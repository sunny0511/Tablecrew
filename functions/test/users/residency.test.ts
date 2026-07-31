import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {deriveResidencyRegion} from '../../src/users/residency';

describe('deriveResidencyRegion', () => {
  it('maps +91 to IN', () => {
    assert.equal(deriveResidencyRegion('+919876543210'), 'IN');
  });

  it('maps +1 to US', () => {
    assert.equal(deriveResidencyRegion('+14155551234'), 'US');
  });

  it('maps +44 to GB', () => {
    assert.equal(deriveResidencyRegion('+447911123456'), 'GB');
  });

  it('maps +971 to AE without being shadowed by a shorter prefix', () => {
    assert.equal(deriveResidencyRegion('+971501234567'), 'AE');
  });

  it('maps +61 to AU', () => {
    assert.equal(deriveResidencyRegion('+61412345678'), 'AU');
  });

  it('maps +65 to SG', () => {
    assert.equal(deriveResidencyRegion('+6591234567'), 'SG');
  });

  it('defaults to IN for an unrecognized calling code', () => {
    assert.equal(deriveResidencyRegion('+33612345678'), 'IN');
  });

  it('defaults to IN for a malformed/empty input rather than throwing', () => {
    assert.equal(deriveResidencyRegion(''), 'IN');
  });
});
