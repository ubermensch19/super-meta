import React from 'react';
import { View, Text, Image, ScrollView, Pressable, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

import { Palette, Spacing, Radius } from '../theme';
import { Icon } from '../components/Icon';
import { CompactCard, WideCard, Tile } from '../components/Cards';
import { SEE, CONNECT, RootStackParamList } from '../navigation';
import { useGlasses, connectionText, dotColor } from '../glasses/useGlasses';

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>;

// The feature hub — an editorial layout with a hero action and grouped
// sections, ported from the SwiftUI HomeView.
export default function HomeScreen({ navigation }: Props) {
  const insets = useSafeAreaInsets();
  const glasses = useGlasses();

  return (
    <ScrollView
      style={styles.canvas}
      contentContainerStyle={{ padding: Spacing.lg, paddingTop: insets.top + Spacing.sm, gap: Spacing.xl }}
    >
      {/* Header */}
      <View style={styles.headerRow}>
        <View>
          <View style={styles.brandRow}>
            <Image source={require('../../assets/logomark.png')} style={styles.logo} resizeMode="contain" />
            <Text style={styles.brand}>Super Meta</Text>
          </View>
          <View style={styles.chipRow}>
            <View style={[styles.dot, { backgroundColor: dotColor(glasses) }]} />
            <Text style={styles.chipText}>{connectionText(glasses)}</Text>
          </View>
        </View>
        <Pressable onPress={() => navigation.navigate('Settings')} style={styles.gear}>
          <Icon name="settings" size={18} color={Palette.textSecondary} />
        </Pressable>
      </View>

      {/* Hero — Live AI */}
      <Pressable onPress={() => navigation.navigate('LiveAI')}>
        <LinearGradient
          colors={[Palette.accent, Palette.live]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.hero}
        >
          <View style={styles.heroTop}>
            <Icon name="mic" size={22} color={Palette.canvas} />
            <Icon name="arrow-up-right" size={16} color={Palette.canvas} />
          </View>
          <View style={{ height: Spacing.xl }} />
          <Text style={styles.heroTitle}>Live AI</Text>
          <Text style={styles.heroBody}>Talk to your glasses in real time — it sees and hears with you.</Text>
        </LinearGradient>
      </Pressable>

      {/* See */}
      <Section title="See">
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={{ gap: Spacing.md, paddingRight: Spacing.lg }}
        >
          {SEE.map((f) => (
            <CompactCard
              key={f.route}
              title={f.title}
              subtitle={f.subtitle}
              icon={f.icon}
              tint={f.tint}
              onPress={() => navigation.navigate(f.route)}
            />
          ))}
        </ScrollView>
      </Section>

      {/* Speak */}
      <Section title="Speak">
        <WideCard
          title="Live Translate"
          subtitle="Real-time, across 11 languages"
          icon="globe"
          tint={Palette.positive}
          onPress={() => navigation.navigate('LiveTranslate')}
        />
      </Section>

      {/* Connect */}
      <Section title="Connect">
        <View style={{ flexDirection: 'row', gap: Spacing.md }}>
          {CONNECT.map((f) => (
            <Tile
              key={f.route}
              title={f.title}
              subtitle={f.subtitle}
              icon={f.icon}
              tint={f.tint}
              onPress={() => navigation.navigate(f.route)}
            />
          ))}
        </View>
      </Section>

      {/* Records */}
      <Pressable onPress={() => navigation.navigate('Records')} style={styles.records}>
        <Icon name="clock" size={20} color={Palette.textSecondary} />
        <View style={{ flex: 1, marginLeft: Spacing.md }}>
          <Text style={styles.cardTitle}>Records</Text>
          <Text style={styles.cardSubtitle}>Your saved vision results</Text>
        </View>
        <Icon name="chevron" size={18} color={Palette.textMuted} />
      </Pressable>

      <View style={{ height: insets.bottom + Spacing.lg }} />
    </ScrollView>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={{ gap: Spacing.md }}>
      <Text style={styles.sectionLabel}>{title}</Text>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  canvas: { flex: 1, backgroundColor: Palette.canvas },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  logo: { width: 52, height: 26 },
  brand: { color: Palette.textPrimary, fontSize: 30, fontWeight: '700' },
  chipRow: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 4 },
  dot: { width: 6, height: 6, borderRadius: 3 },
  chipText: { color: Palette.textSecondary, fontSize: 12 },
  gear: {
    padding: 10,
    borderRadius: Radius.pill,
    backgroundColor: Palette.surface,
  },
  hero: { borderRadius: Radius.lg, padding: Spacing.lg, minHeight: 190 },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  heroTitle: { color: Palette.canvas, fontSize: 26, fontWeight: '700' },
  heroBody: { color: Palette.canvas, fontSize: 15, marginTop: 6, opacity: 0.85, maxWidth: '90%' },
  sectionLabel: {
    color: Palette.textMuted,
    fontSize: 13,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  records: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: Radius.md,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
  },
  cardTitle: { color: Palette.textPrimary, fontSize: 17, fontWeight: '600' },
  cardSubtitle: { color: Palette.textSecondary, fontSize: 13, marginTop: 2 },
});
