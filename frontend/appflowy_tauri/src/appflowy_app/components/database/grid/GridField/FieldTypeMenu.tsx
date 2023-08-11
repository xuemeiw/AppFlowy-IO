import { Divider, Menu, MenuItem, MenuProps } from '@mui/material';
import { FC, Fragment, useMemo } from 'react';
import { FieldType } from '@/services/backend';
import { FieldTypeSvg } from './FieldTypeSvg';

const FieldTypeGroup = [
  {
    name: 'Basic',
    types: [
      FieldType.RichText,
      FieldType.Number,
      FieldType.SingleSelect,
      FieldType.MultiSelect,
      FieldType.DateTime,
      FieldType.Checkbox,
      FieldType.Checklist,
    ],
  },
  {
    name: 'Advanced',
    types: [
      FieldType.LastEditedTime,
    ],
  },
];

export const FieldTypeMenu: FC<MenuProps> = (props) => {
  const PopoverClasses = useMemo(() => ({
    ...props.PopoverClasses,
    paper: ['w-56', props.PopoverClasses?.paper].join(' '),
  }), [props.PopoverClasses]);

  return (
    <Menu
      {...props}
      PopoverClasses={PopoverClasses}
    >
      {FieldTypeGroup.map((group, index) => (
        <Fragment key={group.name}>
          <MenuItem dense disabled>{group.name}</MenuItem>
          {group.types.map(type => (
            <MenuItem key={type} dense>
              <FieldTypeSvg className="mr-2 text-base" type={type} />
              <span className="font-medium">{type}</span>
            </MenuItem>
          ))}
          {index < FieldTypeGroup.length - 1 && <Divider />}
        </Fragment>
      ))}
    </Menu>
  )
}