import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Palette, Spacing } from '../theme';

// Stand-in for feature screens not yet ported. Keeps navigation wired end-to-end
// so the shell is fully clickable while individual features get built out.
export default function PlaceholderScreen({ title, blurb }: { title: string; blurb: string }) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.blurb}>{blurb}</Text>
      <Text style={styles.tag}>Coming to the React Native build</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Palette.canvas, padding: Spacing.xl, justifyContent: 'center', gap: Spacing.md },
  title: { color: Palette.textPrimary, fontSize: 30, fontWeight: '700' },
  blurb: { color: Palette.textSecondary, fontSize: 16, lineHeight: 22 },
  tag: { color: Palette.accent, fontSize: 13, fontWeight: '600', marginTop: Spacing.sm },
});
