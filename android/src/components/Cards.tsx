import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { Palette, Spacing, Radius } from '../theme';
import { Icon, IconName } from './Icon';

// A colored, rounded icon chip used on every card.
function IconChip({ icon, tint, size = 44 }: { icon: IconName; tint: string; size?: number }) {
  return (
    <View
      style={[
        styles.chip,
        { width: size, height: size, borderRadius: Radius.sm, backgroundColor: tint + '22' },
      ]}
    >
      <Icon name={icon} size={size * 0.45} color={tint} />
    </View>
  );
}

// Compact card for the horizontal "See" row.
export function CompactCard({
  title,
  subtitle,
  icon,
  tint,
  onPress,
}: {
  title: string;
  subtitle: string;
  icon: IconName;
  tint: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.compact, pressed && styles.pressed]}>
      <IconChip icon={icon} tint={tint} />
      <View style={{ height: Spacing.lg }} />
      <Text style={styles.cardTitle}>{title}</Text>
      <Text style={styles.cardSubtitle}>{subtitle}</Text>
    </Pressable>
  );
}

// Full-width card for the "Speak" section.
export function WideCard({
  title,
  subtitle,
  icon,
  tint,
  onPress,
}: {
  title: string;
  subtitle: string;
  icon: IconName;
  tint: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.wide, pressed && styles.pressed]}>
      <IconChip icon={icon} tint={tint} />
      <View style={{ flex: 1, marginLeft: Spacing.md }}>
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardSubtitle}>{subtitle}</Text>
      </View>
      <Icon name="chevron" size={18} color={Palette.textMuted} />
    </Pressable>
  );
}

// Half-width tile for the "Connect" pair.
export function Tile({
  title,
  subtitle,
  icon,
  tint,
  onPress,
}: {
  title: string;
  subtitle: string;
  icon: IconName;
  tint: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.tile, pressed && styles.pressed]}>
      <IconChip icon={icon} tint={tint} size={38} />
      <View style={{ height: Spacing.md }} />
      <Text style={styles.cardTitle}>{title}</Text>
      <Text style={styles.cardSubtitle}>{subtitle}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: { alignItems: 'center', justifyContent: 'center' },
  pressed: { opacity: 0.6 },
  cardTitle: { color: Palette.textPrimary, fontSize: 17, fontWeight: '600' },
  cardSubtitle: { color: Palette.textSecondary, fontSize: 13, marginTop: 2 },
  compact: {
    width: 168,
    padding: Spacing.md,
    borderRadius: Radius.md,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
  },
  wide: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.md,
    borderRadius: Radius.md,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
  },
  tile: {
    flex: 1,
    padding: Spacing.md,
    borderRadius: Radius.md,
    backgroundColor: Palette.surface,
    borderWidth: 1,
    borderColor: Palette.border,
  },
});
