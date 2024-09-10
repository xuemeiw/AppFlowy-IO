import { ReactComponent as AppFlowyLogo } from '@/assets/appflowy.svg';
import { ReactComponent as SideOutlined } from '@/assets/side_outlined.svg';
import Resizer from '@/components/_shared/outline/Resizer';
import AppFlowyPower from '../appflowy-power/AppFlowyPower';
import { createHotKeyLabel, HOT_KEY_NAME } from '@/utils/hotkeys';
import { Drawer, IconButton, Tooltip } from '@mui/material';
import { useTranslation } from 'react-i18next';

export function OutlineDrawer ({ open, width, onClose, children, onResizeWidth }: {
  open: boolean;
  width: number;
  onClose: () => void;
  children: React.ReactNode;
  onResizeWidth: (width: number) => void;
}) {
  const { t } = useTranslation();

  return (
    <Drawer
      sx={{
        width,
        flexShrink: 0,
        boxShadow: 'var(--shadow)',
        '& .MuiDrawer-paper': {
          width,
          boxSizing: 'border-box',
          borderColor: 'var(--line-divider)',
          boxShadow: 'none',
        },
      }}
      variant="persistent"
      anchor="left"
      open={open}
      tabIndex={0}
      autoFocus
      PaperProps={{
        sx: {
          borderRadius: 0,
        },
      }}
    >

      <div className={'flex h-full relative min-h-full flex-col overflow-y-auto overflow-x-hidden appflowy-scroller'}>
        <div style={{
          backdropFilter: 'blur(4px)',
        }} className={'flex transform-gpu z-10 h-[48px] sticky top-0 items-center justify-between p-4'}
        >
          <div
            className={'flex cursor-pointer items-center gap-1 text-text-title'}
            onClick={() => {
              window.open('https://appflowy.io', '_blank');
            }}
          >
            <AppFlowyLogo className={'w-[88px]'} />
          </div>
          <Tooltip
            title={
              <div className={'flex flex-col'}>
                <span>{t('sideBar.closeSidebar')}</span>
                <span className={'text-xs text-text-caption'}>{createHotKeyLabel(HOT_KEY_NAME.TOGGLE_SIDEBAR)}</span>
              </div>
            }
          >
            <IconButton onClick={onClose}>
              <SideOutlined className={'h-4 w-4 text-text-caption rotate-180 transform'} />
            </IconButton>
          </Tooltip>
        </div>
        <div className={'flex h-fit flex-1 flex-col'}>
          {children}
        </div>
        <AppFlowyPower width={width} />

      </div>
      <Resizer drawerWidth={width} onResize={onResizeWidth} />

    </Drawer>
  );
}

export default OutlineDrawer;