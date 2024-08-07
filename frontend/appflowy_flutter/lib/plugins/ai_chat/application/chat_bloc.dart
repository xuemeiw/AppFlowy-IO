import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nanoid/nanoid.dart';

import 'chat_message_listener.dart';
import 'chat_message_service.dart';

part 'chat_bloc.g.dart';
part 'chat_bloc.freezed.dart';

const sendMessageErrorKey = "sendMessageError";
const systemUserId = "system";
const aiResponseUserId = "0";

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required ViewPB view,
    required UserProfilePB userProfile,
  })  : listener = ChatMessageListener(chatId: view.id),
        chatId = view.id,
        super(
          ChatState.initial(view, userProfile),
        ) {
    _startListening();
    _dispatch();
  }

  final ChatMessageListener listener;
  final String chatId;

  /// The last streaming message id
  String lastStreamMessageId = '';

  /// Using a temporary map to associate the real message ID with the last streaming message ID.
  ///
  /// When a message is streaming, it does not have a real message ID. To maintain the relationship
  /// between the real message ID and the last streaming message ID, we use this map to store the associations.
  ///
  /// This map will be updated when receiving a message from the server and its author type
  /// is 3 (AI response).
  final HashMap<String, String> temporaryMessageIDMap = HashMap();

  @override
  Future<void> close() async {
    if (state.answerStream != null) {
      await state.answerStream?.dispose();
    }
    await listener.stop();
    return super.close();
  }

  void _dispatch() {
    on<ChatEvent>(
      (event, emit) async {
        await event.when(
          initialLoad: () {
            final payload = LoadNextChatMessagePB(
              chatId: state.view.id,
              limit: Int64(10),
            );
            AIEventLoadNextMessage(payload).send().then(
              (result) {
                result.fold((list) {
                  if (!isClosed) {
                    final messages =
                        list.messages.map(_createTextMessage).toList();
                    add(ChatEvent.didLoadLatestMessages(messages));
                  }
                }, (err) {
                  Log.error("Failed to load messages: $err");
                });
              },
            );
          },
          // Loading messages
          startLoadingPrevMessage: () async {
            Int64? beforeMessageId;
            final oldestMessage = _getOlderstMessage();
            if (oldestMessage != null) {
              beforeMessageId = Int64.parseInt(oldestMessage.id);
            }
            _loadPrevMessage(beforeMessageId);
            emit(
              state.copyWith(
                loadingPreviousStatus: const LoadingState.loading(),
              ),
            );
          },
          didLoadPreviousMessages: (List<Message> messages, bool hasMore) {
            Log.debug("did load previous messages: ${messages.length}");
            final onetimeMessages = _getOnetimeMessages();
            final allMessages = _perminentMessages();
            final uniqueMessages = {...allMessages, ...messages}.toList()
              ..sort((a, b) => b.id.compareTo(a.id));

            uniqueMessages.insertAll(0, onetimeMessages);

            emit(
              state.copyWith(
                messages: uniqueMessages,
                loadingPreviousStatus: const LoadingState.finish(),
                hasMorePrevMessage: hasMore,
              ),
            );
          },
          didLoadLatestMessages: (List<Message> messages) {
            final onetimeMessages = _getOnetimeMessages();
            final allMessages = _perminentMessages();
            final uniqueMessages = {...allMessages, ...messages}.toList()
              ..sort((a, b) => b.id.compareTo(a.id));
            uniqueMessages.insertAll(0, onetimeMessages);
            emit(
              state.copyWith(
                messages: uniqueMessages,
                initialLoadingStatus: const LoadingState.finish(),
              ),
            );
          },
          // streaming message
          streaming: (Message message) {
            final allMessages = _perminentMessages();
            allMessages.insert(0, message);
            emit(
              state.copyWith(
                messages: allMessages,
                streamingState: const StreamingState.streaming(),
                canSendMessage: false,
              ),
            );
          },
          finishStreaming: () {
            emit(
              state.copyWith(
                streamingState: const StreamingState.done(),
                canSendMessage:
                    state.sendingState == const SendMessageState.done(),
              ),
            );
          },
          didUpdateAnswerStream: (AnswerStream stream) {
            emit(state.copyWith(answerStream: stream));
          },
          stopStream: () async {
            if (state.answerStream == null) {
              return;
            }

            final payload = StopStreamPB(chatId: chatId);
            await AIEventStopStream(payload).send();
            final allMessages = _perminentMessages();
            if (state.streamingState != const StreamingState.done()) {
              // If the streaming is not started, remove the message from the list
              if (!state.answerStream!.hasStarted) {
                allMessages.removeWhere(
                  (element) => element.id == lastStreamMessageId,
                );
                lastStreamMessageId = "";
              }

              // when stop stream, we will set the answer stream to null. Which means the streaming
              // is finished or canceled.
              emit(
                state.copyWith(
                  messages: allMessages,
                  answerStream: null,
                  streamingState: const StreamingState.done(),
                ),
              );
            }
          },
          receveMessage: (Message message) {
            final allMessages = _perminentMessages();
            // remove message with the same id
            allMessages.removeWhere((element) => element.id == message.id);
            allMessages.insert(0, message);
            emit(
              state.copyWith(
                messages: allMessages,
              ),
            );
          },
          sendMessage: (String message, Map<String, dynamic>? metadata) async {
            unawaited(_startStreamingMessage(message, metadata, emit));
            final allMessages = _perminentMessages();
            emit(
              state.copyWith(
                lastSentMessage: null,
                messages: allMessages,
                relatedQuestions: [],
                sendingState: const SendMessageState.sending(),
                canSendMessage: false,
              ),
            );
          },
          finishSending: (ChatMessagePB message) {
            emit(
              state.copyWith(
                lastSentMessage: message,
                sendingState: const SendMessageState.done(),
                canSendMessage:
                    state.streamingState == const StreamingState.done(),
              ),
            );
          },
          // related question
          didReceiveRelatedQuestion: (List<RelatedQuestionPB> questions) {
            if (questions.isEmpty) {
              return;
            }

            final allMessages = _perminentMessages();
            final message = CustomMessage(
              metadata: OnetimeShotType.relatedQuestion.toMap(),
              author: const User(id: systemUserId),
              id: systemUserId,
            );
            allMessages.insert(0, message);
            emit(
              state.copyWith(
                messages: allMessages,
                relatedQuestions: questions,
              ),
            );
          },
          clearReleatedQuestion: () {
            emit(
              state.copyWith(
                relatedQuestions: [],
              ),
            );
          },
        );
      },
    );
  }

  void _startListening() {
    listener.start(
      chatMessageCallback: (pb) {
        if (!isClosed) {
          // 3 mean message response from AI
          if (pb.authorType == 3 && lastStreamMessageId.isNotEmpty) {
            temporaryMessageIDMap[pb.messageId.toString()] =
                lastStreamMessageId;
            lastStreamMessageId = "";
          }

          final message = _createTextMessage(pb);
          add(ChatEvent.receveMessage(message));
        }
      },
      chatErrorMessageCallback: (err) {
        if (!isClosed) {
          Log.error("chat error: ${err.errorMessage}");
          add(const ChatEvent.finishStreaming());
        }
      },
      latestMessageCallback: (list) {
        if (!isClosed) {
          final messages = list.messages.map(_createTextMessage).toList();
          add(ChatEvent.didLoadLatestMessages(messages));
        }
      },
      prevMessageCallback: (list) {
        if (!isClosed) {
          final messages = list.messages.map(_createTextMessage).toList();
          add(ChatEvent.didLoadPreviousMessages(messages, list.hasMore));
        }
      },
      finishStreamingCallback: () {
        if (!isClosed) {
          add(const ChatEvent.finishStreaming());
          // The answer strema will bet set to null after the streaming is finished or canceled.
          // so if the answer stream is null, we will not get related question.
          if (state.lastSentMessage != null && state.answerStream != null) {
            final payload = ChatMessageIdPB(
              chatId: chatId,
              messageId: state.lastSentMessage!.messageId,
            );
            //  When user message was sent to the server, we start gettting related question
            AIEventGetRelatedQuestion(payload).send().then((result) {
              if (!isClosed) {
                result.fold(
                  (list) {
                    add(ChatEvent.didReceiveRelatedQuestion(list.items));
                  },
                  (err) {
                    Log.error("Failed to get related question: $err");
                  },
                );
              }
            });
          }
        }
      },
    );
  }

// Returns the list of messages that are not include one-time messages.
  List<Message> _perminentMessages() {
    final allMessages = state.messages.where((element) {
      return !(element.metadata?.containsKey(onetimeShotType) == true);
    }).toList();

    return allMessages;
  }

  List<Message> _getOnetimeMessages() {
    final messages = state.messages.where((element) {
      return (element.metadata?.containsKey(onetimeShotType) == true);
    }).toList();

    return messages;
  }

  Message? _getOlderstMessage() {
    // get the last message that is not a one-time message
    final message = state.messages.lastWhereOrNull((element) {
      return !(element.metadata?.containsKey(onetimeShotType) == true);
    });
    return message;
  }

  void _loadPrevMessage(Int64? beforeMessageId) {
    final payload = LoadPrevChatMessagePB(
      chatId: state.view.id,
      limit: Int64(10),
      beforeMessageId: beforeMessageId,
    );
    AIEventLoadPrevMessage(payload).send();
  }

  Future<void> _startStreamingMessage(
    String message,
    Map<String, dynamic>? metadata,
    Emitter<ChatState> emit,
  ) async {
    if (state.answerStream != null) {
      await state.answerStream?.dispose();
    }

    final answerStream = AnswerStream();
    add(ChatEvent.didUpdateAnswerStream(answerStream));

    final payload = StreamChatPayloadPB(
      chatId: state.view.id,
      message: message,
      messageType: ChatMessageTypePB.User,
      textStreamPort: Int64(answerStream.nativePort),
      metadata: await metadataPBFromMetadata(metadata),
    );

    // Stream message to the server
    final result = await AIEventStreamMessage(payload).send();
    result.fold(
      (ChatMessagePB question) {
        if (!isClosed) {
          add(ChatEvent.finishSending(question));

          final questionMessageId = question.messageId;
          final message = _createTextMessage(question);
          add(ChatEvent.receveMessage(message));

          final streamAnswer =
              _createStreamMessage(answerStream, questionMessageId);
          add(ChatEvent.streaming(streamAnswer));
        }
      },
      (err) {
        if (!isClosed) {
          Log.error("Failed to send message: ${err.msg}");
          final metadata = OnetimeShotType.invalidSendMesssage.toMap();
          if (err.code != ErrorCode.Internal) {
            metadata[sendMessageErrorKey] = err.msg;
          }

          final error = CustomMessage(
            metadata: metadata,
            author: const User(id: systemUserId),
            id: systemUserId,
          );

          add(ChatEvent.receveMessage(error));
        }
      },
    );
  }

  Message _createStreamMessage(AnswerStream stream, Int64 questionMessageId) {
    final streamMessageId = (questionMessageId + 1).toString();

    lastStreamMessageId = streamMessageId;

    return TextMessage(
      author: User(id: "streamId:${nanoid()}"),
      metadata: {
        "$AnswerStream": stream,
        "question": questionMessageId,
        "chatId": chatId,
      },
      id: streamMessageId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      text: '',
    );
  }

  Message _createTextMessage(ChatMessagePB message) {
    String messageId = message.messageId.toString();

    /// If the message id is in the temporary map, we will use the previous fake message id
    if (temporaryMessageIDMap.containsKey(messageId)) {
      messageId = temporaryMessageIDMap[messageId]!;
    }

    return TextMessage(
      author: User(id: message.authorId),
      id: messageId,
      text: message.content,
      createdAt: message.createdAt.toInt() * 1000,
      metadata: {
        "metadata": message.metadata,
      },
    );
  }
}

@freezed
class ChatEvent with _$ChatEvent {
  const factory ChatEvent.initialLoad() = _InitialLoadMessage;

  // send message
  const factory ChatEvent.sendMessage({
    required String message,
    Map<String, dynamic>? metadata,
  }) = _SendMessage;
  const factory ChatEvent.finishSending(ChatMessagePB message) =
      _FinishSendMessage;

// receive message
  const factory ChatEvent.streaming(Message message) = _StreamingMessage;
  const factory ChatEvent.receveMessage(Message message) = _ReceiveMessage;
  const factory ChatEvent.finishStreaming() = _FinishStreamingMessage;

// loading messages
  const factory ChatEvent.startLoadingPrevMessage() = _StartLoadPrevMessage;
  const factory ChatEvent.didLoadPreviousMessages(
    List<Message> messages,
    bool hasMore,
  ) = _DidLoadPreviousMessages;
  const factory ChatEvent.didLoadLatestMessages(List<Message> messages) =
      _DidLoadMessages;

// related questions
  const factory ChatEvent.didReceiveRelatedQuestion(
    List<RelatedQuestionPB> questions,
  ) = _DidReceiveRelatedQueston;
  const factory ChatEvent.clearReleatedQuestion() = _ClearRelatedQuestion;

  const factory ChatEvent.didUpdateAnswerStream(
    AnswerStream stream,
  ) = _DidUpdateAnswerStream;
  const factory ChatEvent.stopStream() = _StopStream;
}

@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    required ViewPB view,
    required List<Message> messages,
    required UserProfilePB userProfile,
    // When opening the chat, the initial loading status will be set as loading.
    //After the initial loading is done, the status will be set as finished.
    required LoadingState initialLoadingStatus,
    // When loading previous messages, the status will be set as loading.
    // After the loading is done, the status will be set as finished.
    required LoadingState loadingPreviousStatus,
    // When sending a user message, the status will be set as loading.
    // After the message is sent, the status will be set as finished.
    required StreamingState streamingState,
    required SendMessageState sendingState,
    // Indicate whether there are more previous messages to load.
    required bool hasMorePrevMessage,
    // The related questions that are received after the user message is sent.
    required List<RelatedQuestionPB> relatedQuestions,
    // The last user message that is sent to the server.
    ChatMessagePB? lastSentMessage,
    AnswerStream? answerStream,
    @Default(true) bool canSendMessage,
  }) = _ChatState;

  factory ChatState.initial(ViewPB view, UserProfilePB userProfile) =>
      ChatState(
        view: view,
        messages: [],
        userProfile: userProfile,
        initialLoadingStatus: const LoadingState.finish(),
        loadingPreviousStatus: const LoadingState.finish(),
        streamingState: const StreamingState.done(),
        sendingState: const SendMessageState.done(),
        hasMorePrevMessage: true,
        relatedQuestions: [],
      );
}

bool isOtherUserMessage(Message message) {
  return message.author.id != aiResponseUserId &&
      message.author.id != systemUserId &&
      !message.author.id.startsWith("streamId:");
}

@freezed
class LoadingState with _$LoadingState {
  const factory LoadingState.loading() = _Loading;
  const factory LoadingState.finish({FlowyError? error}) = _Finish;
}

enum OnetimeShotType {
  unknown,
  sendingMessage,
  relatedQuestion,
  invalidSendMesssage,
}

const onetimeShotType = "OnetimeShotType";

extension OnetimeMessageTypeExtension on OnetimeShotType {
  static OnetimeShotType fromString(String value) {
    switch (value) {
      case 'OnetimeShotType.relatedQuestion':
        return OnetimeShotType.relatedQuestion;
      case 'OnetimeShotType.invalidSendMesssage':
        return OnetimeShotType.invalidSendMesssage;
      default:
        Log.error('Unknown OnetimeShotType: $value');
        return OnetimeShotType.unknown;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      onetimeShotType: toString(),
    };
  }
}

OnetimeShotType? onetimeMessageTypeFromMeta(Map<String, dynamic>? metadata) {
  if (metadata == null) {
    return null;
  }

  for (final entry in metadata.entries) {
    if (entry.key == onetimeShotType) {
      return OnetimeMessageTypeExtension.fromString(entry.value as String);
    }
  }
  return null;
}

class AnswerStream {
  AnswerStream() {
    _port.handler = _controller.add;
    _subscription = _controller.stream.listen(
      (event) {
        if (event.startsWith("data:")) {
          _hasStarted = true;
          final newText = event.substring(5);
          _text += newText;
          if (_onData != null) {
            _onData!(_text);
          }
        } else if (event.startsWith("error:")) {
          _error = event.substring(5);
          if (_onError != null) {
            _onError!(_error!);
          }
        } else if (event.startsWith("metadata:")) {
          if (_onMetadata != null) {
            final s = event.substring(9);
            _onMetadata!(chatMessageMetadataFromString(s));
          }
        } else if (event == "AI_RESPONSE_LIMIT") {
          if (_onAIResponseLimit != null) {
            _onAIResponseLimit!();
          }
        }
      },
      onDone: () {
        if (_onEnd != null) {
          _onEnd!();
        }
      },
      onError: (error) {
        if (_onError != null) {
          _onError!(error.toString());
        }
      },
    );
  }

  final RawReceivePort _port = RawReceivePort();
  final StreamController<String> _controller = StreamController.broadcast();
  late StreamSubscription<String> _subscription;
  bool _hasStarted = false;
  String? _error;
  String _text = "";

  // Callbacks
  void Function(String text)? _onData;
  void Function()? _onStart;
  void Function()? _onEnd;
  void Function(String error)? _onError;
  void Function()? _onAIResponseLimit;
  void Function(List<ChatMessageMetadata> metadata)? _onMetadata;

  int get nativePort => _port.sendPort.nativePort;
  bool get hasStarted => _hasStarted;
  String? get error => _error;
  String get text => _text;

  Future<void> dispose() async {
    await _controller.close();
    await _subscription.cancel();
    _port.close();
  }

  void listen({
    void Function(String text)? onData,
    void Function()? onStart,
    void Function()? onEnd,
    void Function(String error)? onError,
    void Function()? onAIResponseLimit,
    void Function(List<ChatMessageMetadata> metadata)? onMetadata,
  }) {
    _onData = onData;
    _onStart = onStart;
    _onEnd = onEnd;
    _onError = onError;
    _onAIResponseLimit = onAIResponseLimit;
    _onMetadata = onMetadata;

    if (_onStart != null) {
      _onStart!();
    }
  }
}

List<ChatMessageMetadata> chatMessageMetadataFromString(String? s) {
  if (s == null || s.isEmpty || s == "null") {
    return [];
  }

  final List<ChatMessageMetadata> metadata = [];
  try {
    final metadataJson = jsonDecode(s);
    if (metadataJson == null) {
      Log.warn("metadata is null");
      return [];
    }

    if (metadataJson is Map<String, dynamic>) {
      if (metadataJson.isNotEmpty) {
        metadata.add(ChatMessageMetadata.fromJson(metadataJson));
      }
    } else if (metadataJson is List) {
      metadata.addAll(
        metadataJson.map(
          (e) => ChatMessageMetadata.fromJson(e as Map<String, dynamic>),
        ),
      );
    } else {
      Log.error("Invalid metadata: $metadataJson");
    }
  } catch (e) {
    Log.error("Failed to parse metadata: $e");
  }

  return metadata;
}

@JsonSerializable()
class ChatMessageMetadata {
  ChatMessageMetadata({
    required this.id,
    required this.name,
    required this.source,
  });

  factory ChatMessageMetadata.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageMetadataFromJson(json);

  final String id;
  final String name;
  final String source;

  Map<String, dynamic> toJson() => _$ChatMessageMetadataToJson(this);
}

@freezed
class StreamingState with _$StreamingState {
  const factory StreamingState.streaming() = _Streaming;
  const factory StreamingState.done({FlowyError? error}) = _StreamDone;
}

@freezed
class SendMessageState with _$SendMessageState {
  const factory SendMessageState.sending() = _Sending;
  const factory SendMessageState.done({FlowyError? error}) = _SendDone;
}
