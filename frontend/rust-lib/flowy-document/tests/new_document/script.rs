use flowy_document::editor::AppFlowyDocumentEditor;

use flowy_test::helper::ViewTest;
use flowy_test::FlowySDKTest;
use lib_ot::core::{NodeOperation, Path, Transaction};
use lib_ot::text_delta::TextOperations;
use std::sync::Arc;

pub enum EditScript {
    InsertText { path: Path, delta: TextOperations },
    AssertContent { expected: &'static str },
}

pub struct DocumentEditorTest {
    pub sdk: FlowySDKTest,
    pub editor: Arc<AppFlowyDocumentEditor>,
}

impl DocumentEditorTest {
    pub async fn new() -> Self {
        let sdk = FlowySDKTest::new(true);
        let _ = sdk.init_user().await;

        let test = ViewTest::new_document_view(&sdk).await;
        let document_editor = sdk.document_manager.open_document_editor(&test.view.id).await.unwrap();
        let editor = match document_editor.as_any().downcast_ref::<Arc<AppFlowyDocumentEditor>>() {
            None => panic!(),
            Some(editor) => editor.clone(),
        };

        Self { sdk, editor }
    }

    pub async fn run_scripts(self, scripts: Vec<EditScript>) {
        for script in scripts {
            self.run_script(script).await;
        }
    }

    async fn run_script(&self, script: EditScript) {
        match script {
            EditScript::InsertText { path, delta: _ } => {
                let operation = NodeOperation::Insert { path, nodes: vec![] };
                self.editor
                    .apply_transaction(Transaction::from_operations(vec![operation]))
                    .await
                    .unwrap();
            }
            EditScript::AssertContent { expected } => {
                //
                let content = self.editor.get_content().await.unwrap();
                assert_eq!(content, expected);
            }
        }
    }
}
