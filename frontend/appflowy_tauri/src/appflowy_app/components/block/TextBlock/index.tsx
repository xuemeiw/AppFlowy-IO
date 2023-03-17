import BlockComponent from '../BlockList/BlockComponent';
import { Slate, Editable } from 'slate-react';
import Leaf from './Leaf';
import HoveringToolbar from '$app/components/HoveringToolbar';
import { TreeNode } from '@/appflowy_app/block_editor/tree_node';
import { useTextBlock } from './index.hooks';
import { BlockCommonProps, TextBlockToolbarProps } from '@/appflowy_app/interfaces';
import { toolbarDefaultProps } from '@/appflowy_app/constants/toolbar';

export default function TextBlock({
  node,
  needRenderChildren = true,
  toolbarProps,
  ...props
}: {
  needRenderChildren?: boolean;
  toolbarProps?: TextBlockToolbarProps;
} & BlockCommonProps<TreeNode> &
  React.HTMLAttributes<HTMLDivElement>) {
  const { editor, value, onChange, onKeyDownCapture } = useTextBlock({ node });
  const { showGroups } = toolbarProps || toolbarDefaultProps;

  return (
    <div {...props} className={props.className + ' py-1'}>
      <Slate editor={editor} onChange={onChange} value={value}>
        {showGroups.length > 0 && <HoveringToolbar node={node} blockId={node.id} />}
        <Editable
          onKeyDownCapture={onKeyDownCapture}
          onDOMBeforeInput={(e) => {
            // COMPAT: in Apple, `compositionend` is dispatched after the
            // `beforeinput` for "insertFromComposition". It will cause repeated characters when inputting Chinese.
            // Here, prevent the beforeInput event and wait for the compositionend event to take effect
            if (e.inputType === 'insertFromComposition') {
              e.preventDefault();
            }
          }}
          renderLeaf={(leafProps) => <Leaf {...leafProps} />}
          placeholder='Enter some text...'
        />
      </Slate>
      {needRenderChildren && node.children.length > 0 ? (
        <div className='pl-[1.5em]'>
          {node.children.map((item) => (
            <BlockComponent key={item.id} node={item} />
          ))}
        </div>
      ) : null}
    </div>
  );
}
