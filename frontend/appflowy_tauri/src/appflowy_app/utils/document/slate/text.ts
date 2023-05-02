import { Editor, Element, Text, Location } from 'slate';
import { SelectionPoint, TextDelta, TextSelection } from '$app/interfaces/document';

export function getDelta(editor: Editor, at: Location): TextDelta[] {
  const baseElement = Editor.fragment(editor, at)[0] as Element;
  return baseElement.children.map((item) => {
    const { text, ...attributes } = item as Text;
    return {
      insert: text,
      attributes,
    };
  });
}

/**
 * get the selection between the beginning of the editor and the point
 * form 0 to point
 * @param editor
 * @param at
 */
export function getBeforeRangeAt(editor: Editor, at: Location) {
  const start = Editor.start(editor, at);
  return {
    anchor: { path: [0, 0], offset: 0 },
    focus: start,
  };
}

/**
 * get the selection between the point and the end of the editor
 * from point to end
 * @param editor
 * @param at
 */
export function getAfterRangeAt(editor: Editor, at: Location) {
  const end = Editor.end(editor, at);
  const fragment = (editor.children[0] as Element).children;
  const lastIndex = fragment.length - 1;
  const lastNode = fragment[lastIndex] as Text;
  return {
    anchor: end,
    focus: { path: [0, lastIndex], offset: lastNode.text.length },
  };
}

/**
 * check if the point is in the beginning of the editor
 * @param editor
 * @param at
 */
export function pointInBegin(editor: Editor, at: Location) {
  const start = Editor.start(editor, at);
  return Editor.before(editor, start) === undefined;
}

/**
 * check if the point is in the end of the editor
 * @param editor
 * @param at
 */
export function pointInEnd(editor: Editor, at: Location) {
  const end = Editor.end(editor, at);
  return Editor.after(editor, end) === undefined;
}

/**
 * get the selection of the beginning of the node
 */
export function getNodeBeginSelection(): TextSelection {
  const point: SelectionPoint = {
    path: [0, 0],
    offset: 0,
  };
  const selection: TextSelection = {
    anchor: clonePoint(point),
    focus: clonePoint(point),
  };
  return selection;
}

/**
 * get the selection of the end of the node
 * @param delta
 */
export function getNodeEndSelection(delta: TextDelta[]) {
  const len = delta.length;
  const offset = len > 0 ? delta[len - 1].insert.length : 0;

  const cursorPoint: SelectionPoint = {
    path: [0, Math.max(len - 1, 0)],
    offset,
  };

  const selection: TextSelection = {
    anchor: clonePoint(cursorPoint),
    focus: clonePoint(cursorPoint),
  };
  return selection;
}

/**
 * get lines by delta
 * @param delta
 */
export function getLinesByDelta(delta: TextDelta[]): string[] {
  const text = delta.map((item) => item.insert).join('');
  return text.split('\n');
}

/**
 * get the offset of the last line
 * @param delta
 */
export function getLastLineOffsetByDelta(delta: TextDelta[]): number {
  const text = delta.map((item) => item.insert).join('');
  const index = text.lastIndexOf('\n');
  return index === -1 ? 0 : index + 1;
}

/**
 * get the selection of the end line by offset
 * @param delta
 * @param offset relative offset of the end line
 */
export function getEndLineSelectionByOffset(delta: TextDelta[], offset: number) {
  const lines = getLinesByDelta(delta);
  const endLine = lines[lines.length - 1];
  // if the offset is greater than the length of the end line, set cursor to the end of prev line
  if (offset >= endLine.length) {
    return getNodeEndSelection(delta);
  }

  const textOffset = getLastLineOffsetByDelta(delta) + offset;
  return getSelectionByTextOffset(delta, textOffset);
}

/**
 * get the selection of the start line by offset
 * @param delta
 * @param offset relative offset of the start line
 */
export function getStartLineSelectionByOffset(delta: TextDelta[], offset: number) {
  const lines = getLinesByDelta(delta);
  if (lines.length === 0) {
    return getNodeBeginSelection();
  }
  const startLine = lines[0];
  // if the offset is greater than the length of the end line, set cursor to the end of prev line
  if (offset >= startLine.length) {
    return getSelectionByTextOffset(delta, startLine.length);
  }

  return getSelectionByTextOffset(delta, offset);
}

/**
 * get the selection by text offset
 * @param delta
 * @param offset absolute offset
 */
export function getSelectionByTextOffset(delta: TextDelta[], offset: number) {
  const point = getPointByTextOffset(delta, offset);
  const selection: TextSelection = {
    anchor: clonePoint(point),
    focus: clonePoint(point),
  };
  return selection;
}

/**
 * get the point by text offset
 * @param delta
 * @param offset absolute offset
 */
export function getPointByTextOffset(delta: TextDelta[], offset: number): SelectionPoint {
  let textOffset = 0;
  let path: [number, number] = [0, 0];
  let textLength = 0;
  for (let i = 0; i < delta.length; i++) {
    const item = delta[i];
    if (textOffset + item.insert.length >= offset) {
      path = [0, i];
      textLength = offset - textOffset;
      break;
    }
    textOffset += item.insert.length;
  }

  return {
    path,
    offset: textLength,
  };
}

export function clonePoint(point: SelectionPoint): SelectionPoint {
  return {
    path: [...point.path],
    offset: point.offset,
  };
}
