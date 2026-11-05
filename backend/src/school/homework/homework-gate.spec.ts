import { InFlightGate } from './homework-gate';

describe('InFlightGate', () => {
  it('admits up to the limit, refuses beyond it and admits again after a leave', () => {
    const gate = new InFlightGate(2);

    expect(gate.tryEnter()).toBe(true);
    expect(gate.tryEnter()).toBe(true);
    expect(gate.tryEnter()).toBe(false);
    expect(gate.inFlight).toBe(2);

    gate.leave();

    expect(gate.tryEnter()).toBe(true);
  });

  it('never goes negative on a stray leave', () => {
    const gate = new InFlightGate(1);

    gate.leave();
    gate.leave();

    expect(gate.inFlight).toBe(0);
    expect(gate.tryEnter()).toBe(true);
    expect(gate.tryEnter()).toBe(false);
  });

  it('a limit of zero refuses everything', () => {
    expect(new InFlightGate(0).tryEnter()).toBe(false);
  });
});
