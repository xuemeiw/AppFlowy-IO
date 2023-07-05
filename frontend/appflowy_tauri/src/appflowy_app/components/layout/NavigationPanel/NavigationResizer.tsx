import { useResizer } from '../../_shared/useResizer';
import { useAppDispatch, useAppSelector } from '$app/stores/store';
import { useEffect } from 'react';
import { navigationWidthActions } from '$app_reducers/navigation-width/slice';

export const NavigationResizer = ({ minWidth }: { minWidth: number }) => {
  const width = useAppSelector((state) => state.navigationWidth);
  const appDispatch = useAppDispatch();
  const { onMouseDown, newSizeX } = useResizer();

  useEffect(() => {
    if (newSizeX < minWidth) {
      appDispatch(navigationWidthActions.changeWidth(minWidth));
    } else {
      appDispatch(navigationWidthActions.changeWidth(newSizeX));
    }
  }, [newSizeX]);

  return (
    <button
      className={'fixed z-10 h-full w-[15px] cursor-ew-resize'}
      style={{ left: `${width - 8}px`, userSelect: 'none' }}
      onMouseDown={(e) => onMouseDown(e, width)}
    ></button>
  );
};
