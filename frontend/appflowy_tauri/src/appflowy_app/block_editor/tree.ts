import { BlockPositionManager } from "./position";
import { BlockChain, BlockChangeProps } from './block_chain';
import { Block } from './block';
import { TreeNode } from "./tree_node";

export class RenderTree {
  private positionManager: BlockPositionManager;
  private map: Map<string, TreeNode> = new Map();

  constructor(private blockChain: BlockChain) {
    this.positionManager = new BlockPositionManager();
  }

  /**
   * Get the TreeNode data by nodeId
   * @param nodeId string
   * @returns TreeNode|null
   */
  getTreeNode = (nodeId: string): TreeNode | null => {
    // Return the TreeNode instance from the map or null if it does not exist
    return this.map.get(nodeId) || null;
  }

  private createNode(block: Block): TreeNode {
    if (this.map.has(block.id)) {
      return this.map.get(block.id)!;
    }
    const node = new TreeNode(block, {
      getRect: (id: string) => this.positionManager.getBlockPosition(id),
    });
    this.map.set(block.id, node);
    return node;
  }


  buildDeep(rootId: string): TreeNode | null {
    this.map.clear();
    // Define a callback function for the blockChain.traverse() method
    const callback = (block: Block) => {
      // Check if the TreeNode instance already exists in the map
      const node = this.createNode(block);

      // Add the TreeNode instance to the map
      this.map.set(block.id, node);

      // Add the first child of the block as a child of the current TreeNode instance
      const firstChild = block.firstChild;
      if (firstChild) {
        const child = this.createNode(firstChild);
        node.addChild(child);
        this.map.set(child.id, child);
      }

      // Add the next block as a sibling of the current TreeNode instance
      const next = block.next;
      if (next) {
        const nextNode = this.createNode(next);
        node.parent?.addChild(nextNode);
        this.map.set(next.id, nextNode);
      }
    }

    // Traverse the blockChain using the callback function
    this.blockChain.traverse(callback);

    // Get the root node from the map and return it
    const root = this.map.get(rootId);
    return root || null;
  }


  observeNode(blockId: string, el: HTMLDivElement) {
    const node = this.getTreeNode(blockId);
    if (!node) return;
    return this.positionManager.observeBlock(node, el);
  }

  updateBlockPosition(blockId: string) {
    const node = this.getTreeNode(blockId);
    if (!node) return;
    this.positionManager.updateBlock(node.id);
  }

  updateViewportBlocks() {
    this.positionManager.updateViewportBlocks();
  }

  rebuild(nodeId: string): TreeNode | null {
    const block = this.blockChain.getBlock(nodeId);
    if (!block) return null;
    const node = this.createNode(block);
    if (!node) return null;

    const children: TreeNode[] = [];
    let childBlock = block.firstChild;

    while(childBlock) {
      const child = this.createNode(childBlock);
      child.update(childBlock, child.children);
      children.push(child);
      childBlock = childBlock.next;
    }

    node.update(block, children);

    console.log(node);

    return node;
  }

  reRender(nodeId: string) {
    const node = this.rebuild(nodeId);
    node?.reRender();
  }

  onBlockChange(command: string, data: BlockChangeProps) {
    const { block, startBlock, endBlock, oldParentId = '', oldPrevId = '' } = data;
    switch (command) {
      case 'insert':
        if (block?.parent) this.reRender(block.parent.id);
        break;
      case 'update':
        this.reRender(block!.id);
        break;
      case 'move':
        if (oldParentId) this.reRender(oldParentId);
        if (block?.parent) this.reRender(block.parent.id);
        if (startBlock?.parent) this.reRender(startBlock.parent.id);
        break;
      default:
        break;
    }
    if (block) {
      this.updateBlockPosition(block.id);
    } else if (startBlock) {
      this.updateBlockPosition(startBlock.id);
    } else if (endBlock) {
      this.updateBlockPosition(endBlock.id);
    } else if (oldParentId) {
      this.updateBlockPosition(oldParentId);
    } else if (oldPrevId) {
      this.updateBlockPosition(oldPrevId);
    }
  }

  /**
   * Destroy the RenderTreeRectManager instance
   */
  destroy() {
    this.positionManager?.destroy();
  }
}
