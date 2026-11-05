import { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Button, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  buildScheduleTable,
  formatTime,
  getNextPrayer,
  getPrayers,
  GRACE_MINUTES,
} from './src/prayerTimes';
import PrayerLock, { PrayerSchedule } from './modules/prayer-lock';

// Turns today's remaining prayers into schedules for Swift.
// Only includes locks at least a minute away, so iOS has time to register them.
function upcomingSchedules(now: Date): PrayerSchedule[] {
  return getPrayers(now)
    .filter((p) => p.lockAt.getTime() > now.getTime() + 60 * 1000)
    .map((p) => ({
      name: p.name,
      hour: p.lockAt.getHours(),
      minute: p.lockAt.getMinutes(),
    }));
}

// A test schedule 2–3 minutes from now, starting on a whole minute.
function testSchedule(now: Date, name: string): PrayerSchedule {
  const start = new Date(now);
  start.setSeconds(0, 0);
  start.setMinutes(start.getMinutes() + 3);
  return { name, hour: start.getHours(), minute: start.getMinutes() };
}

// Schedules that shouldn't be cancelled by reopening the app.
const TEST_NAMES = ['Test', 'DailyTest'];

export default function App() {
  const [now, setNow] = useState(new Date());
  const [authStatus, setAuthStatus] = useState(PrayerLock?.authorizationStatus() ?? 'unavailable');
  const [appCount, setAppCount] = useState(PrayerLock?.allowedAppCount() ?? 0);
  const [active, setActive] = useState<string[]>(PrayerLock?.activeSchedules() ?? []);
  const [log, setLog] = useState(PrayerLock?.readLog() ?? '');
  const [message, setMessage] = useState('');

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 30 * 1000);
    return () => clearInterval(timer);
  }, []);

  // When the app opens, save the timetable and schedule today's remaining prayers.
  // Skipped while a test is waiting, so reopening the app doesn't cancel it.
  useEffect(() => {
    if (!PrayerLock || PrayerLock.authorizationStatus() !== 'approved') return;
    if (PrayerLock.activeSchedules().some((name) => TEST_NAMES.includes(name))) return;
    schedule();
  }, []);

  const prayers = getPrayers(now);
  const next = getNextPrayer(prayers, now);

  // Reads the latest values from Swift and updates the screen.
  const refresh = () => {
    if (!PrayerLock) return;
    setAuthStatus(PrayerLock.authorizationStatus());
    setAppCount(PrayerLock.allowedAppCount());
    setActive(PrayerLock.activeSchedules());
    setLog(PrayerLock.readLog());
  };

  // Saves the timetable, then registers today's remaining prayers,
  // plus a test schedule if one is given.
  const schedule = (testName?: string) => {
    if (!PrayerLock) return;
    const current = new Date();

    PrayerLock.saveScheduleTable(JSON.stringify(buildScheduleTable()));

    const list = upcomingSchedules(current);
    if (testName) list.push(testSchedule(current, testName));

    const count = PrayerLock.schedulePrayers(list);
    setMessage(`Scheduled ${count} lock(s).`);
    refresh();
  };

  const requestAccess = async () => {
    try {
      await PrayerLock?.requestAuthorization();
      setMessage('Approved');
    } catch (e) {
      setMessage(`Failed: ${String(e)}`);
    }
    refresh();
  };

  const pickApps = async () => {
    try {
      const count = await PrayerLock?.pickApps();
      setMessage(`Saved ${count} allowed apps`);
    } catch (e) {
      setMessage(`Picker failed: ${String(e)}`);
    }
    refresh();
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
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

        <Text style={styles.section}>Lock (test)</Text>
        {PrayerLock ? (
          <>
            <Text>Screen Time access: {authStatus}</Text>
            <Button title="Request Screen Time access" onPress={requestAccess} />
            <Text>Allowed apps: {appCount}</Text>
            <Button title="Choose allowed apps" onPress={pickApps} />

            <Text style={styles.label}>
              Active schedules: {active.length ? active.join(', ') : 'none'}
            </Text>
            <Button title="Schedule today's prayers" onPress={() => schedule()} />
            <Button title="Test lock in about 2 minutes" onPress={() => schedule('Test')} />
            <Button title="Test midnight job in about 2 minutes" onPress={() => schedule('DailyTest')} />

            <Button title="Lock now" color="#c62828" onPress={() => { PrayerLock?.lockNow(); refresh(); }} />
            <Button title="I've prayed" color="#2e7d32" onPress={() => { PrayerLock?.unlock(); refresh(); }} />
            {message ? <Text style={styles.message}>{message}</Text> : null}

            <Text style={styles.section}>Log</Text>
            <Text style={styles.log}>{log}</Text>
            <Button title="Refresh log" onPress={refresh} />
            <Button title="Clear log" onPress={() => { PrayerLock?.clearLog(); refresh(); }} />
          </>
        ) : (
          <Text style={styles.message}>
            The lock isn't available here. It needs the TrollStore build, not Expo Go.
          </Text>
        )}
      </ScrollView>
      <StatusBar style="auto" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff' },
  content: { paddingHorizontal: 20, paddingTop: 40, paddingBottom: 60 },
  title: { fontSize: 32, fontWeight: 'bold' },
  subtitle: { fontSize: 18, color: '#555', marginTop: 4, marginBottom: 24 },
  header: { flexDirection: 'row', paddingVertical: 8, borderBottomWidth: 1, borderColor: '#ddd' },
  headerText: { fontWeight: '600', color: '#888' },
  row: { flexDirection: 'row', paddingVertical: 14, borderBottomWidth: 1, borderColor: '#eee' },
  nextRow: { backgroundColor: '#e8f5e9', borderRadius: 8 },
  cell: { flex: 1, fontSize: 18, paddingHorizontal: 8 },
  nextText: { fontWeight: 'bold', color: '#1b5e20' },
  note: { marginTop: 24, color: '#888' },
  section: { fontSize: 20, fontWeight: 'bold', marginTop: 32, marginBottom: 8 },
  label: { marginTop: 12 },
  message: { marginTop: 8, color: '#555' },
  log: { fontFamily: 'Courier', fontSize: 12, marginBottom: 8 },
});