import { List } from "build/dev/javascript/prelude.mjs"

function argsFromList(args: List<any>): Array<any> {
  return args.toArray().map((i) => i.inner)
}

export function call_method_bool(obj: any, method: string, args: List<any>): boolean {
  return obj[method](...argsFromList(args))
}
