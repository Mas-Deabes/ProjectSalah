import { requireOptionalNativeModule } from 'expo';

type AuthStatus = 'approved' | 'denied' | 'notDetermined' | 'unknown';

// Describes the Swift functions in PrayerLockModule.swift,
// so TypeScript knows their names, inputs and return types.
type PrayerLockNative = {
  authorizationStatus(): AuthStatus;
  requestAuthorization(): Promise<void>;
  allowedAppCount(): number;
  pickApps(): Promise<number>;
  lockNow(): void;
  unlock(): void;
  readLog(): string;
  clearLog(): void;
};

// Finds the native module named "PrayerLock".
// Returns null in Expo Go (and on Android for now), where it doesn't exist.
const PrayerLock = requireOptionalNativeModule<PrayerLockNative>('PrayerLock');

export default PrayerLock;