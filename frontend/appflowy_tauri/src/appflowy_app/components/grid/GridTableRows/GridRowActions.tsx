import { useRef } from 'react';
import useOutsideClick from '../../_shared/useOutsideClick';
import AddSvg from '../../_shared/svg/AddSvg';
import { CopySvg } from '../../_shared/svg/CopySvg';
import { TrashSvg } from '../../_shared/svg/TrashSvg';
import { ShareSvg } from '../../_shared/svg/ShareSvg';
import { DatabaseController } from '@/appflowy_app/stores/effects/database/database_controller';
import { useGridRowActions } from './GridRowActions.hooks';

export const GridRowActions = ({
  onOutsideClick,
  controller,
  rowId,
}: {
  onOutsideClick: () => void;
  controller: DatabaseController;
  rowId: string;
}) => {
  const ref = useRef<HTMLDivElement>(null);
  useOutsideClick(ref, onOutsideClick);

  const { deleteRow,duplicateRow,insertRowAfter } = useGridRowActions(controller);

  return (
    <div className='absolute left-20 ml-1 mt-2 w-44 bg-white ' ref={ref}>
      <div className='flex flex-col gap-3 rounded-lg bg-white p-2 shadow-md'>
        <button className='flex cursor-pointer items-center rounded  p-1 text-gray-500 hover:bg-main-secondary hover:text-black'
         onClick={async () => {
            await insertRowAfter(rowId);
          }}>
          <div className='flex gap-2'>
            <div className='h-5 w-5'>
              <AddSvg />
            </div>
            <span>Insert Record</span>
          </div>
        </button>
        <button className='flex cursor-pointer items-center rounded  p-1 text-gray-500 hover:bg-main-secondary hover:text-black'>
          <div className='flex gap-2'>
            <div className='h-5 w-5'>
              <ShareSvg />
            </div>
            <span>Copy Link</span>
          </div>
        </button>
        <button className='flex cursor-pointer items-center rounded  p-1 text-gray-500 hover:bg-main-secondary hover:text-black'
        
         onClick={async () => {
            await duplicateRow(rowId);
          }}>
          <div className='flex gap-2'>
            <div className='h-5 w-5'>
              <CopySvg />
            </div>
            <span>Duplicate</span>
          </div>
        </button>
        <button
          className='flex cursor-pointer items-center rounded  p-1 text-gray-500 hover:bg-main-secondary hover:text-black'
          onClick={async () => {
            await deleteRow(rowId);
          }}
        >
          <div className='flex gap-2'>
            <div className='h-5 w-5'>
              <TrashSvg />
            </div>
            <span>Delete</span>
          </div>
        </button>
      </div>
    </div>
  );
};
