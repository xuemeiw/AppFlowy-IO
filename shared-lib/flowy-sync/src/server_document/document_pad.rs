use crate::synchronizer::RevisionOperations;
use crate::{client_document::InitialDocument, errors::CollaborateError, synchronizer::RevisionSyncObject};
use lib_ot::{core::*, text_delta::DeltaTextOperations};

pub struct ServerDocument {
    document_id: String,
    operations: DeltaTextOperations,
}

impl ServerDocument {
    #[allow(dead_code)]
    pub fn new<C: InitialDocument>(doc_id: &str) -> Self {
        let operations = DeltaTextOperations::from_json(&C::json_str()).unwrap();
        Self::from_operations(doc_id, operations)
    }

    pub fn from_operations(document_id: &str, operations: DeltaTextOperations) -> Self {
        let document_id = document_id.to_owned();
        ServerDocument {
            document_id,
            operations,
        }
    }
}

impl RevisionSyncObject<AttributeHashMap> for ServerDocument {
    fn object_id(&self) -> &str {
        &self.document_id
    }

    fn object_json(&self) -> String {
        self.operations.json_str()
    }

    fn compose(&mut self, other: &DeltaTextOperations) -> Result<(), CollaborateError> {
        let operations = self.operations.compose(other)?;
        self.operations = operations;
        Ok(())
    }

    fn transform(
        &self,
        other: &DeltaTextOperations,
    ) -> Result<(DeltaTextOperations, DeltaTextOperations), CollaborateError> {
        let value = self.operations.transform(other)?;
        Ok(value)
    }

    fn set_operations(&mut self, operations: RevisionOperations<AttributeHashMap>) {
        self.operations = operations;
    }
}
