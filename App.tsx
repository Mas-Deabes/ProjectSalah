import { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { formatTime, getNextPrayer, getPrayers, GRACE_MINUTES } from './src/prayerTimes';

export default function App() {
  const [now, setNow] = useState(new Date());

  // Update "now" every 30 seconds so the next prayer moves on by itself.
  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 30 * 1000);
    return () => clearInterval(timer);
  }, []);

  const prayers = getPrayers(now);
  const next = getNextPrayer(prayers, now);

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>ProjectSalah</Text>
      <Text style={styles.subtitle}>
        {next ? `Next: ${next.name} at ${formatTime(next.athan)}` : 'All prayers done for today'}
      </Text>

      <View style={styles.header}>
        <Text style={[styles.cell, styles.headerText]}>Prayer</Text>
        <Text style={[styles.cell, styles.headerText]}>Athan</Text>
        <Text style={[styles.cell, styles.headerText]}>Lock at</Text>
      </View>

      {prayers.map((p) => {
        const isNext = next?.name === p.name;
        return (
          <View key={p.name} style={[styles.row, isNext && styles.nextRow]}>
            <Text style={[styles.cell, isNext && styles.nextText]}>{p.name}</Text>
            <Text style={[styles.cell, isNext && styles.nextText]}>{formatTime(p.athan)}</Text>
            <Text style={[styles.cell, isNext && styles.nextText]}>{formatTime(p.lockAt)}</Text>
          </View>
        );
      })}

      <Text style={styles.note}>Apps lock {GRACE_MINUTES} minutes after each athan.</Text>
      <StatusBar style="auto" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', paddingHorizontal: 20, paddingTop: 40 },
  title: { fontSize: 32, fontWeight: 'bold' },
  subtitle: { fontSize: 18, color: '#555', marginTop: 4, marginBottom: 24 },
  header: { flexDirection: 'row', paddingVertical: 8, borderBottomWidth: 1, borderColor: '#ddd' },
  headerText: { fontWeight: '600', color: '#888' },
  row: { flexDirection: 'row', paddingVertical: 14, borderBottomWidth: 1, borderColor: '#eee' },
  nextRow: { backgroundColor: '#e8f5e9', borderRadius: 8 },
  cell: { flex: 1, fontSize: 18, paddingHorizontal: 8 },
  nextText: { fontWeight: 'bold', color: '#1b5e20' },
  note: { marginTop: 24, color: '#888' },
});