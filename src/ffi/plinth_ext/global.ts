import { Result, Ok, Error } from "build/dev/javascript/prelude.mjs";

export function set_global(key: string, val: string): void {
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
