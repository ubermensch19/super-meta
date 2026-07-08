import React, { useLayoutEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  Pressable,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  StyleSheet,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

import { Palette, Spacing, Radius } from '../theme';
import { Icon } from '../components/Icon';
import { useGateway } from '../gateway/GatewayProvider';
import { Trace } from '../gateway/GatewayClient';
import { RootStackParamList } from '../navigation';

type Props = NativeStackScreenProps<RootStackParamList, 'AgentSession'>;

const DOT: Record<string, string> = {
  connected: Palette.positive,
  connecting: Palette.accent,
  waitingForPairing: Palette.accent,
  error: Palette.live,
  disconnected: Palette.textMuted,
};

// The live agent session: a chat feed of "working traces" (what the agent runs on
// the glasses) plus a user chat input. Spawned when the node connects.
export default function AgentSessionScreen({ navigation }: Props) {
  const gw = useGateway();
  const insets = useSafeAreaInsets();
  const [draft, setDraft] = useState('');
  const list = useRef<FlatList<Trace>>(null);

  useLayoutEffect(() => {
    navigation.setOptions({
      headerRight: () => (
        <View style={styles.headerRight}>
          <View style={[styles.dot, { backgroundColor: DOT[gw.state] ?? Palette.textMuted }]} />
          <Text style={styles.headerNode}>{gw.nodeID}</Text>
        </View>
      ),
    });
  }, [navigation, gw.state, gw.nodeID]);

  const send = () => {
    const t = draft.trim();
    if (!t) return;
    gw.sendChat(t);
    setDraft('');
  };

  return (
    <KeyboardAvoidingView
      style={styles.canvas}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={90}
    >
      <FlatList
        ref={list}
        data={gw.traces}
        keyExtractor={(t) => t.id}
        contentContainerStyle={{ padding: Spacing.lg, gap: Spacing.sm }}
        onContentSizeChange={() => list.current?.scrollToEnd({ animated: true })}
        ListEmptyComponent={
          <Text style={styles.empty}>
            Waiting for the agent… When it runs commands on your glasses (camera.snap,
            device.status), they'll appear here. You can chat below.
          </Text>
        }
        renderItem={({ item }) => <TraceRow t={item} />}
      />

      <View style={[styles.composer, { paddingBottom: insets.bottom + Spacing.sm }]}>
        <TextInput
          style={styles.input}
          value={draft}
          onChangeText={setDraft}
          placeholder="Message the agent…"
          placeholderTextColor={Palette.textMuted}
          onSubmitEditing={send}
          returnKeyType="send"
        />
        <Pressable onPress={send} style={({ pressed }) => [styles.sendBtn, pressed && { opacity: 0.6 }]}>
          <Icon name="arrow-up-right" size={18} color={Palette.canvas} />
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

function TraceRow({ t }: { t: Trace }) {
  if (t.kind === 'user') {
    return (
      <View style={[styles.bubble, styles.user]}>
        <Text style={styles.userText}>{t.text}</Text>
      </View>
    );
  }
  if (t.kind === 'system') {
    return (
      <View style={styles.system}>
        <Text style={styles.systemText}>{t.text}{t.detail ? ` · ${t.detail}` : ''}</Text>
      </View>
    );
  }
  const tint = t.kind === 'error' ? Palette.live : Palette.accent;
  return (
    <View style={[styles.bubble, styles.agent]}>
      <View style={styles.agentHead}>
        <Icon name={t.kind === 'error' ? 'broadcast' : 'antenna'} size={13} color={tint} />
        <Text style={[styles.agentLabel, { color: tint }]}>{t.kind === 'error' ? 'Error' : 'Agent'}</Text>
      </View>
      <Text style={styles.agentText}>{t.text}</Text>
      {!!t.detail && <Text style={styles.detail}>{t.detail}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  canvas: { flex: 1, backgroundColor: Palette.canvas },
  headerRight: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  dot: { width: 7, height: 7, borderRadius: 4 },
  headerNode: { color: Palette.textSecondary, fontSize: 12, fontVariant: ['tabular-nums'] },
  empty: { color: Palette.textMuted, fontSize: 14, lineHeight: 20, textAlign: 'center', marginTop: Spacing.xl },
  bubble: { maxWidth: '85%', padding: Spacing.md, borderRadius: Radius.md },
  agent: {
    alignSelf: 'flex-start',
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
    gap: 4,
  },
  agentHead: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  agentLabel: { fontSize: 11, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 0.4 },
  agentText: { color: Palette.textPrimary, fontSize: 15 },
  detail: { color: Palette.textSecondary, fontSize: 12, fontVariant: ['tabular-nums'] },
  user: { alignSelf: 'flex-end', backgroundColor: Palette.accent },
  userText: { color: Palette.canvas, fontSize: 15, fontWeight: '500' },
  system: { alignSelf: 'center', paddingVertical: 2 },
  systemText: { color: Palette.textMuted, fontSize: 12 },
  composer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingTop: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: Palette.border,
    backgroundColor: Palette.canvas,
  },
  input: {
    flex: 1,
    color: Palette.textPrimary,
    fontSize: 16,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
    borderRadius: Radius.pill,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Palette.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
