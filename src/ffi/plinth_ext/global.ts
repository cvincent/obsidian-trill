import { Result, Ok, Error } from "build/dev/javascript/prelude.mjs";

export function set_global(key: string, val: any): void {
  let w = window as any;
  w["lustre-globals"] ||= {};
  w[key] = val;
}

export function get_string(key: string): Result<string, null> {
  let w = window as any;
  let val = w[key] as string;

  if (val) return new Ok(val);
  else return new Error(null);
}

export function get_int(key: string): Result<number, null> {
  let w = window as any;
  let val = w[key] as string;

  if (val) return new Ok(val);
  else return new Error(null);
}

export function get_timer_id(key: string): Result<number, null> {
  let w = window as any;
  let val = w[key] as string;

  if (val) return new Ok(val);
  else return new Error(null);
}
