import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createSocialServer } from '../server.mjs';

async function fixture(t) {
  const dataDir = await mkdtemp(path.join(os.tmpdir(), 'opennow-social-'));
  const service = createSocialServer({ dataDir, host: '127.0.0.1' });
  const address = await service.listen(0);
  const origin = `http://127.0.0.1:${address.port}`;
  t.after(async () => { await service.close(); await rm(dataDir, { recursive: true, force: true }); });
  async function request(route, { method = 'GET', token, body } = {}) {
    const headers = {};
    if (token) headers.authorization = `Bearer ${token}`;
    if (body !== undefined) headers['content-type'] = 'application/json';
    const response = await fetch(`${origin}${route}`, {
      method, headers, body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  }
  return { request, dataDir };
}

async function register(request, username, nvidiaDisplayName = '') {
  const response = await request('/v1/auth/register', {
    method: 'POST', body: { username, password: 'correct-horse-battery-staple', nvidiaDisplayName },
  });
  assert.equal(response.status, 201, JSON.stringify(response.body));
  return response.body;
}

test('health endpoint responds without an account', async t => {
  const { request } = await fixture(t);
  assert.deepEqual((await request('/healthz')).body, { ok: true, service: 'opennow-social' });
});

test('registration, OpenNOW friend codes, privacy defaults, and unverified NVIDIA names', async t => {
  const { request, dataDir } = await fixture(t);
  const account = await register(request, 'Mira_Player', 'MiraGfn');
  assert.ok(account.token.length >= 40);
  assert.match(account.user.friendCode, /^ON-[A-F0-9]{12}$/);
  assert.equal(account.user.nvidiaDisplayName, 'MiraGfn');
  assert.equal(account.user.nvidiaDisplayNameVerified, false);
  assert.equal(JSON.stringify(account.user).includes('passwordHash'), false);
  assert.deepEqual(account.privacy, { sharePresence: false, shareActivity: false, shareHistory: false });
  const linkedName = await request('/v1/profile', { method: 'PUT', token: account.token,
    body: { nvidiaDisplayName: 'ChangedName' } });
  assert.equal(linkedName.body.user.nvidiaDisplayName, 'ChangedName');
  assert.equal(linkedName.body.user.nvidiaDisplayNameVerified, false);
  assert.equal((await request('/v1/auth/register', {
    method: 'POST', body: { username: 'mira_player', password: 'correct-horse-battery-staple' },
  })).status, 409);
  assert.equal((await request('/v1/auth/register', {
    method: 'POST', body: { username: 'ab', password: 'too-short' },
  })).status, 400);
  const file = await stat(path.join(dataDir, 'social-db.json'));
  assert.equal(file.mode & 0o777, 0o600);
});

test('concurrent registration cannot claim one username twice', async t => {
  const { request } = await fixture(t);
  const payload = { method: 'POST', body: { username: 'Concurrent', password: 'correct-horse-battery-staple' } };
  const responses = await Promise.all([request('/v1/auth/register', payload), request('/v1/auth/register', payload)]);
  assert.deepEqual(responses.map(response => response.status).sort(), [201, 409]);
});

test('friend request acceptance enables cross-account plain-text chat and presence', async t => {
  const { request } = await fixture(t);
  const alice = await register(request, 'Alice');
  const bob = await register(request, 'Bob', 'BobGfn');
  assert.equal((await request('/v1/friend-requests', {
    method: 'POST', token: alice.token, body: { identifier: bob.user.friendCode },
  })).status, 201);
  const requests = await request('/v1/friend-requests', { token: bob.token });
  assert.equal(requests.body.requests.length, 1);
  assert.equal(requests.body.requests[0].nvidiaDisplayNameVerified, false);
  assert.equal((await request(`/v1/friend-requests/${alice.user.id}/accept`, {
    method: 'POST', token: bob.token, body: {},
  })).status, 200);
  assert.deepEqual((await request('/v1/friends', { token: alice.token })).body.friends.map(f => f.id), [bob.user.id]);
  assert.equal((await request(`/v1/friends/${bob.user.id}/messages`, {
    method: 'POST', token: alice.token, body: { text: 'Hello from another computer 👋' },
  })).status, 201);
  const chat = await request(`/v1/friends/${alice.user.id}/messages`, { token: bob.token });
  assert.equal(chat.body.messages.length, 1);
  assert.equal(chat.body.messages[0].text, 'Hello from another computer 👋');
  assert.equal(chat.body.messages[0].senderId, alice.user.id);
  await request('/v1/privacy', { method: 'PUT', token: bob.token,
    body: { sharePresence: true, shareActivity: true, shareHistory: true } });
  await request('/v1/presence', { method: 'PUT', token: bob.token,
    body: { status: 'online', activity: { gameId: 'g-42', gameName: 'Example Game' } } });
  const profile = (await request('/v1/friends', { token: alice.token })).body.friends[0];
  assert.equal(profile.online, true);
  assert.equal(profile.activity.gameName, 'Example Game');
  await new Promise(resolve => setTimeout(resolve, 1050));
  await request('/v1/presence', { method: 'PUT', token: bob.token,
    body: { status: 'online', activity: { gameId: 'g-42', gameName: 'Example Game' } } });
  const withHistory = (await request('/v1/friends', { token: alice.token })).body.friends[0];
  assert.equal(withHistory.recentGames[0].gameName, 'Example Game');
  assert.ok(withHistory.recentGames[0].playTimeMs >= 1000);
  await request('/v1/privacy', { method: 'PUT', token: bob.token,
    body: { sharePresence: true, shareActivity: false, shareHistory: false } });
  const privateProfile = (await request('/v1/friends', { token: alice.token })).body.friends[0];
  assert.equal(privateProfile.activity, null);
  assert.deepEqual(privateProfile.recentGames, []);
  await request('/v1/privacy', { method: 'PUT', token: bob.token,
    body: { sharePresence: true, shareActivity: true, shareHistory: true } });
  assert.equal((await request(`/v1/friends/${bob.user.id}/messages`, {
    method: 'POST', token: alice.token, body: { text: '<script>alert(1)</script>' },
  })).body.message.text, '<script>alert(1)</script>');
  assert.equal((await request('/v1/auth/logout', { method: 'POST', token: bob.token, body: {} })).status, 200);
  assert.equal((await request('/v1/friends', { token: alice.token })).body.friends[0].online, false);
});

test('chat is restricted to accepted friends and auth is required', async t => {
  const { request } = await fixture(t);
  const account = await register(request, 'Charlie');
  assert.equal((await request('/v1/friends')).status, 401);
  assert.equal((await request(`/v1/friends/${account.user.id}/messages`, {
    method: 'POST', token: account.token, body: { text: 'self' },
  })).status, 403);
  const logout = await request('/v1/auth/logout', { method: 'POST', token: account.token, body: {} });
  assert.equal(logout.status, 200);
  assert.equal((await request('/v1/me', { token: account.token })).status, 401);
});
