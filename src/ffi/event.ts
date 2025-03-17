export function prevent_default(ev: any): void {
  ev.preventDefault()
}

export function stop_propagation(ev: any): void {
  ev.stopPropagation()
}

export function stop_immediate_propagation(ev: any): void {
  ev.stopImmediatePropagation()
}
