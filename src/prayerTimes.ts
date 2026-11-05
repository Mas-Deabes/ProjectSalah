import { CalculationMethod, Coordinates, Madhab, PrayerTimes } from 'adhan';

// How long the user gets after the athan before apps lock.
export const GRACE_MINUTES = 5;

// How many days of lock times to save for the extension.
export const TABLE_DAYS = 365;

export type PrayerName = 'Fajr' | 'Dhuhr' | 'Asr' | 'Maghrib' | 'Isha';

export type Prayer = {
  name: PrayerName;
  athan: Date;
  lockAt: Date;
};

// One prayer's lock time for the timetable that the extension reads.
export type ScheduleEntry = {
  name: PrayerName;
  hour: number;
  minute: number;
};

// Fixed London coordinates for now. Later this comes from the phone's location.
const LONDON = new Coordinates(51.5074, -0.1278);

export function getPrayers(date: Date = new Date()): Prayer[] {
  const params = CalculationMethod.MoonsightingCommittee();
  params.madhab = Madhab.Shafi;

  const times = new PrayerTimes(LONDON, date, params);

  const list: [PrayerName, Date][] = [
    ['Fajr', times.fajr],
    ['Dhuhr', times.dhuhr],
    ['Asr', times.asr],
    ['Maghrib', times.maghrib],
    ['Isha', times.isha],
  ];

  return list.map(([name, athan]) => ({
    name,
    athan,
    lockAt: new Date(athan.getTime() + GRACE_MINUTES * 60 * 1000),
  }));
}

// The first prayer whose athan hasn't happened yet today, or null after Isha.
export function getNextPrayer(prayers: Prayer[], now: Date = new Date()): Prayer | null {
  return prayers.find((p) => p.athan > now) ?? null;
}

// Formats a Date as "HH:MM" (24-hour).
export function formatTime(date: Date): string {
  const h = date.getHours().toString().padStart(2, '0');
  const m = date.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
}

// A local date as "YYYY-MM-DD". Used as the key for each day in the timetable.
export function dateKey(date: Date): string {
  const y = date.getFullYear();
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// Lock times for the next `days` days, keyed by date.
// Example: { "2026-11-05": [{ name: "Fajr", hour: 6, minute: 5 }, ...], ... }
export function buildScheduleTable(
  days: number = TABLE_DAYS,
  from: Date = new Date(),
): Record<string, ScheduleEntry[]> {
  const table: Record<string, ScheduleEntry[]> = {};

  for (let i = 0; i < days; i++) {
    // Midday on each day, so clock changes at 1am or 2am can't shift the date.
    const day = new Date(from.getFullYear(), from.getMonth(), from.getDate() + i, 12);

    table[dateKey(day)] = getPrayers(day)
      // Skip a lock time that falls after midnight (very late Isha).
      .filter((p) => p.lockAt.getDate() === day.getDate())
      .map((p) => ({
        name: p.name,
        hour: p.lockAt.getHours(),
        minute: p.lockAt.getMinutes(),
      }));
  }

  return table;
}