import { requireOptionalNativeModule } from 'expo';

type AuthStatus = 'approved' | 'denied' | 'notDetermined' | 'unknown';

// One prayer's lock time. Must match the PrayerSchedule Record in Swift.
export type PrayerSchedule = {
  name: string;
  hour: number;
  minute: number;
};

// Describes the Swift functions in PrayerLockModule.swift,
// so TypeScript knows their names, inputs and return types.
type PrayerLockNative = {
  authorizationStatus(): AuthStatus;
  requestAuthorization(): Promise<void>;
  allowedAppCount(): number;
  pickApps(): Promise<number>;
  schedulePrayers(prayers: PrayerSchedule[]): number;
  activeSchedules(): string[];
  lockNow(): void;
  unlock(): void;
  readLog(): string;
  clearLog(): void;
};

// Finds the native module named "PrayerLock".
// Returns null in Expo Go (and on Android for now), where it doesn't exist.
const PrayerLock = requireOptionalNativeModule<PrayerLockNative>('PrayerLock');

export default PrayerLock;