const { initDB } = require('../db');
const { generateForGroup, runFlashbackGeneration } = require('../flashbackJob');

beforeAll(async () => {
  await initDB();
});

describe('Flashback Job', () => {
  it('generateForGroup does not throw when group has no media', () => {
    const emptyGroup = { id: 'non-existent-group-id', name: 'Empty Group' };
    expect(() => {
      generateForGroup(emptyGroup, new Date());
    }).not.toThrow();
  });

  it('runFlashbackGeneration completes without throwing errors', () => {
    expect(() => {
      runFlashbackGeneration();
    }).not.toThrow();
  });
});
