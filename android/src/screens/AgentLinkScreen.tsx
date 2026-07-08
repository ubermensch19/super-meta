import React, { useEffect, useRef } from 'react';
import { View, Text, TextInput, Switch, Pressable, ScrollView, StyleSheet } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

import { Palette, Spacing, Radius } from '../theme';
import { Icon } from '../components/Icon';
import { useGateway } from '../gateway/GatewayProvider';
import { ConnectionState } from '../gateway/GatewayClient';
import { RootStackParamList } from '../navigation';

type Props = NativeStackScreenProps<RootStackParamList, 'AgentLink'>;

const STATUS: Record<ConnectionState, { label: string; color: string }> = {
  disconnected: { label: 'Disconnected', color: Palette.textMuted },
  connecting: { label: 'Connecting…', color: Palette.accent },
  connected: { label: 'Connected', color: Palette.positive },
  waitingForPairing: { label: 'Waiting for pairing', color: Palette.accent },
  error: { label: 'Error', color: Palette.live },
};

export default function AgentLinkScreen({ navigation }: Props) {
  const gw = useGateway();
  const s = STATUS[gw.state];
  const isConnected = gw.state === 'connected';
  const isBusy = gw.state === 'connecting';

  // When the node comes online, spawn the session (chat + working traces).
  const spawned = useRef(false);
  useEffect(() => {
    if ((gw.state === 'connected' || gw.state === 'waitingForPairing') && !spawned.current) {
      spawned.current = true;
      navigation.navigate('AgentSession');
    }
    if (gw.state === 'disconnected') spawned.current = false;
  }, [gw.state, navigation]);

  return (
    <ScrollView style={styles.canvas} contentContainerStyle={{ padding: Spacing.lg, gap: Spacing.lg }}>
      {/* Status */}
      <View style={styles.panel}>
        <View style={styles.row}>
          <View style={styles.badge}>
            <View style={[styles.dot, { backgroundColor: s.color }]} />
            <Text style={[styles.badgeText, { color: s.color }]}>{s.label}</Text>
          </View>
          <Text style={styles.mono}>{gw.nodeID}</Text>
        </View>
        {!!gw.error && <Text style={styles.error}>{gw.error}</Text>}
      </View>

      {/* Config */}
      <View style={{ gap: Spacing.md }}>
        <Field label="Host" value={gw.config.host} onChange={(host) => gw.setConfig({ ...gw.config, host })} autoCapitalize="none" />
        <Field
          label="Port"
          value={String(gw.config.port)}
          onChange={(t) => gw.setConfig({ ...gw.config, port: parseInt(t || '0', 10) || 0 })}
          keyboardType="number-pad"
        />
        <Field
          label="Token (optional)"
          value={gw.config.token}
          onChange={(token) => gw.setConfig({ ...gw.config, token })}
          secureTextEntry
          autoCapitalize="none"
        />
        <View style={[styles.field, styles.toggleRow]}>
          <Text style={styles.label}>Use TLS (wss)</Text>
          <Switch
            value={gw.config.useTLS}
            onValueChange={(useTLS) => gw.setConfig({ ...gw.config, useTLS })}
            trackColor={{ true: Palette.accent, false: Palette.surfaceHigh }}
          />
        </View>
      </View>

      {/* 1-click connect */}
      <Pressable
        disabled={!gw.ready || isBusy}
        onPress={() => (isConnected ? gw.disconnect() : gw.connect())}
        style={({ pressed }) => [
          styles.button,
          { backgroundColor: isConnected ? Palette.surfaceHigh : Palette.accent },
          (pressed || isBusy || !gw.ready) && { opacity: 0.6 },
        ]}
      >
        <Icon name={isConnected ? 'broadcast' : 'antenna'} size={18} color={isConnected ? Palette.textPrimary : Palette.canvas} />
        <Text style={[styles.buttonText, { color: isConnected ? Palette.textPrimary : Palette.canvas }]}>
          {isConnected ? 'Disconnect' : 'Connect'}
        </Text>
      </Pressable>

      <Text style={styles.help}>
        Works with OpenClaw or Hermes gateways. Your glasses join as a node — the agent can run
        camera.snap and device.status.
      </Text>
    </ScrollView>
  );
}

function Field({
  label,
  value,
  onChange,
  keyboardType,
  secureTextEntry,
  autoCapitalize,
}: {
  label: string;
  value: string;
  onChange: (t: string) => void;
  keyboardType?: React.ComponentProps<typeof TextInput>['keyboardType'];
  secureTextEntry?: boolean;
  autoCapitalize?: React.ComponentProps<typeof TextInput>['autoCapitalize'];
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={onChange}
        placeholderTextColor={Palette.textMuted}
        keyboardType={keyboardType}
        secureTextEntry={secureTextEntry}
        autoCapitalize={autoCapitalize}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  canvas: { flex: 1, backgroundColor: Palette.canvas },
  panel: {
    padding: Spacing.md,
    borderRadius: Radius.md,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
    gap: Spacing.sm,
  },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  badge: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  dot: { width: 8, height: 8, borderRadius: 4 },
  badgeText: { fontSize: 14, fontWeight: '600' },
  mono: { color: Palette.textSecondary, fontSize: 12, fontVariant: ['tabular-nums'] },
  error: { color: Palette.live, fontSize: 13 },
  field: {
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    gap: 2,
  },
  toggleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  label: { color: Palette.textMuted, fontSize: 12 },
  input: { color: Palette.textPrimary, fontSize: 16, paddingVertical: 2 },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.md,
    borderRadius: Radius.md,
  },
  buttonText: { fontSize: 16, fontWeight: '700' },
  help: { color: Palette.textMuted, fontSize: 13, lineHeight: 18 },
});
