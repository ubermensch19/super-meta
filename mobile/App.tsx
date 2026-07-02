import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { Palette } from './src/theme';
import HomeScreen from './src/screens/HomeScreen';
import PlaceholderScreen from './src/screens/PlaceholderScreen';
import { RootStackParamList, RouteName, SEE, CONNECT } from './src/navigation';

const Stack = createNativeStackNavigator<RootStackParamList>();

// Detail-screen copy for routes not covered by the SEE/CONNECT feature registry.
const EXTRA: Partial<Record<RouteName, { title: string; blurb: string }>> = {
  LiveAI: {
    title: 'Live AI',
    blurb: 'Real-time voice conversation with on-glasses camera context — Chat, Guide, and Assist modes.',
  },
  LiveTranslate: {
    title: 'Live Translate',
    blurb: 'Speech-to-speech translation across 11 languages, live through your glasses.',
  },
  Records: { title: 'Records', blurb: 'History of your vision results, saved on device.' },
  Settings: { title: 'Settings', blurb: 'Providers, API keys, and glasses pairing.' },
};

const BLURBS: Partial<Record<RouteName, { title: string; blurb: string }>> = Object.fromEntries([
  ...[...SEE, ...CONNECT].map((f) => [f.route, { title: f.title, blurb: f.blurb }]),
  ...Object.entries(EXTRA),
]);

const navTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: Palette.canvas,
    card: Palette.canvas,
    text: Palette.textPrimary,
    border: Palette.border,
    primary: Palette.accent,
  },
};

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <NavigationContainer theme={navTheme}>
        <Stack.Navigator
          screenOptions={{
            headerStyle: { backgroundColor: Palette.canvas },
            headerTintColor: Palette.textPrimary,
            headerShadowVisible: false,
            contentStyle: { backgroundColor: Palette.canvas },
          }}
        >
          <Stack.Screen name="Home" component={HomeScreen} options={{ headerShown: false }} />
          {(Object.keys(BLURBS) as RouteName[]).map((route) => (
            <Stack.Screen key={route} name={route} options={{ title: BLURBS[route]!.title }}>
              {() => <PlaceholderScreen title={BLURBS[route]!.title} blurb={BLURBS[route]!.blurb} />}
            </Stack.Screen>
          ))}
        </Stack.Navigator>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
