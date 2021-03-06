
{Keys,Engine,secure_bufeq,Algos} = require '../../lib/blockcrypt'
{rng,prng} = require 'crypto'
{status} = require '../../lib/constants'

#==================================================================

twiddle_byte = (buf, i) -> buf[i] = (buf[i] + 1) % 0x100

#==================================================================

# Run a test:
#  1. Generate a random block of length psize
#  2. Generate a random key set
#  3. Encrypt the block in step 1.
#  4. Check that the encryption is the right size
#  5. Decrypt and check it against the original
#  6. Corrupt it, and check that it fails the MAC
# 
test = (T, psize, esize) ->
  keys = new Keys prng Keys.raw_length()
  input = prng psize
  eng = new Engine keys
  eblock = eng.encrypt input
  T.assert ((l = eblock.length) is esize), "output block len #{l} != #{esize}"
  [rc,pblock] = eng.decrypt eblock
  T.assert (rc is status.OK), "decryption failed w/ code #{rc}"
  T.assert (secure_bufeq pblock, input), "Failed to get out same block"

  bad = new Buffer eblock
  # Twiddle the first block of the ciphertext
  twiddle_byte bad, Engine.header_size()
  [rc,_] = eng.decrypt bad
  T.assert (rc is status.E_BAD_MAC), "mac should fail on corrupted ciphertext"

  bad = new Buffer eblock
  # Twiddle the third block of the IV
  twiddle_byte bad, 2
  [rc,_] = eng.decrypt bad
  T.assert (rc is status.E_BAD_MAC), "mac should fail on corrupted IV"

  bad = new Buffer eblock
  # Twiddle the last byte of the MAC
  twiddle_byte bad, bad.length - 1
  [rc,_] = eng.decrypt bad
  T.assert (rc is status.E_BAD_MAC), "mac should fail on corrupted MAC"

#==================================================================

exports.test_tiny_1 = (T, cb) ->
  test T, 1, 64
  cb()

exports.test_small_1 = (T, cb) ->
  test T, 15, 64
  cb()

exports.test_med_1 = (T, cb) ->
  isize = 128
  # an input of len 0mod16 incurs a full pad 
  osize = isize + Algos.S.enc.block*2 + Algos.S.hmac.key
  test T, isize, osize
  cb()

exports.test_full_1 = (T, cb) ->
  osize = 1024*1024
  isize = Engine.input_size osize
  test T, isize, osize
  cb()

#==================================================================
