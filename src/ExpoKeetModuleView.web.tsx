import * as React from 'react';

import { ExpoKeetModuleViewProps } from './ExpoKeetModule.types';

export default function ExpoKeetModuleView(props: ExpoKeetModuleViewProps) {
  return (
    <div>
      <span>{props.name}</span>
    </div>
  );
}
