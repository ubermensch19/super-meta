import React, { useEffect, useState } from 'react';
import { View, Text, TextInput, Pressable, ScrollView, StyleSheet } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

import { Palette, Spacing, Radius } from '../theme';
import { Icon } from '../components/Icon';
import {
  RTMP_PRESETS,
  isRtmpAvailable,
  startStream,
  stopStream,
  useRtmpStatus,
} from '../streaming/rtmp';

const STATUS: Record<string, { label: string; color: string }> = {
  idle: { label: 'Idle', color: Palette.textMuted },
  connecting: { label: 'Connecting…', color: Palette.accent },
  streaming: { label: 'Live', color: Palette.live },
  error: { label: 'Error', color: Palette.live },
};

// Broadcast the glasses camera over RTMP — port of the native RTMPStreamView.
export default function LiveStreamScreen() {
  const status = useRtmpStatus();
  const [url, setUrl] = useState('');
  const [streamKey, setStreamKey] = useState('');
  const s = STATUS[status.state];
  const isLive = status.state === 'streaming' || status.state === 'connecting';

  useEffect(() => {
    AsyncStorage.getItem('rtmp_url').then((v) => v && setUrl(v));
  }, []);

  const setUrlPersist = (v: string) => {
    setUrl(v);
    void AsyncStorage.setItem('rtmp_url', v);
  };

  const go = () => {
    if (isLive) void stopStream();
    else if (url) void startStream(url, streamKey);
  };

  return (
    <ScrollView style={styles.canvas} contentContainerStyle={{ padding: Spacing.lg, gap: Spacing.lg }}>
      <View style={styles.panel}>
        <View style={styles.row}>
          <View style={styles.badge}>
            <View style={[styles.dot, { backgroundColor: s.color }]} />
            <Text style={[styles.badgeText, { color: s.color }]}>{s.label}</Text>
          </View>
          <Text style={styles.mono}>{status.framesSent} frames</Text>
        </View>
        {!!status.error && <Text style={styles.error}>{status.error}</Text>}
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: Spacing.sm }}>
        {RTMP_PRESETS.map((p) => (
          <Pressable
            key={p.name}
            onPress={() => p.url && setUrlPersist(p.url)}
            style={styles.chip}
          >
            <Text style={styles.chipText}>{p.name}</Text>
          </Pressable>
        ))}
      </ScrollView>

      <Field label="RTMP URL" value={url} onChange={setUrlPersist} placeholder="rtmp://…" />
      <Field label="Stream key" value={streamKey} onChange={setStreamKey} secureTextEntry />

      <Pressable
        onPress={go}
        disabled={!isRtmpAvailable || (!url && !isLive)}
        style={({ pressed }) => [
          styles.button,
          { backgroundColor: isLive ? Palette.surfaceHigh : Palette.live },
          (pressed || !isRtmpAvailable || (!url && !isLive)) && { opacity: 0.55 },
        ]}
      >
        <Icon name="broadcast" size={18} color={isLive ? Palette.textPrimary : Palette.canvas} />
        <Text style={[styles.buttonText, { color: isLive ? Palette.textPrimary : Palette.canvas }]}>
          {isLive ? 'Stop streaming' : 'Go live'}
        </Text>
      </Pressable>

      {!isRtmpAvailable && (
        <Text style={styles.help}>
          Streaming the glasses camera needs the native RTMP encoder — available in a dev build
          with your glasses connected, not in Expo Go.
        </Text>
      )}
    </ScrollView>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  secureTextEntry,
}: {
  label: string;
  value: string;
  onChange: (t: string) => void;
  placeholder?: string;
  secureTextEntry?: boolean;
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={styles.input}
        value={value}
        onChangeText={onChange}
        placeholder={placeholder}
        placeholderTextColor={Palette.textMuted}
        autoCapitalize="none"
        secureTextEntry={secureTextEntry}
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
  chip: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: Radius.pill,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
  },
  chipText: { color: Palette.textSecondary, fontSize: 13 },
  field: {
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    gap: 2,
  },
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
