import { registerWebModule, NativeModule } from 'expo';

class ExpoGlassesModule extends NativeModule<{}> {}

export default registerWebModule(ExpoGlassesModule, 'ExpoGlassesModule');
