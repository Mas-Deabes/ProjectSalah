import { CalculationMethod, Coordinates, Madhab, PrayerTimes } from 'adhan';

// How long the user gets after the athan before apps lock.
export const GRACE_MINUTES = 5;

export type PrayerName = 'Fajr' | 'Dhuhr' | 'Asr' | 'Maghrib' | 'Isha';

export type Prayer = {
  name: PrayerName;
  athan: Date;
  lockAt: Date;
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