/** Convert API ISO datetime to value for <input type="datetime-local"> */
export function toDateTimeLocalValue(value?: string | null): string {
  if (!value) return '';
  const match = value.match(/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/);
  if (match) return `${match[1]}T${match[2]}`;
  return '';
}

/** Convert datetime-local input value to ISO string for the API */
export function toIsoDateTime(localValue?: string | null): string | null {
  if (!localValue) return null;
  return localValue.length === 16 ? `${localValue}:00` : localValue;
}

/** Format ISO datetime for display in tables */
export function formatDateTimeDisplay(value?: string | null): string {
  if (!value) return '—';
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/);
  if (!match) return value;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const month = months[parseInt(match[2], 10) - 1];
  const day = parseInt(match[3], 10);
  const year = match[1];
  const hours = parseInt(match[4], 10);
  const minutes = match[5];
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const h12 = hours % 12 || 12;
  return `${month} ${day}, ${year} ${h12}:${minutes} ${ampm}`;
}
