extends Node

## Play the sounds of the game (see section 11 of DESIGN.md). The music is
## synthesized here: the plucked strings of a dombra (Karplus-Strong) play the
## background music (the melody of "Көзімнің қарасы" by Abai, in the public
## domain), the celebration tune and the clicks. The steppe is recorded: the
## hooves of the horse in its gaits, its whinny and its snort, the calls of the
## animals, the birds and the marmots, the locusts, the wind and the insects
## in the grass, all cut from recordings under CC0 into assets/sounds/ by
## dev/sounds/cut_sounds.py (see THIRD_PARTY_NOTICES.md).
##
## The sounds are made the first time they are played and kept. The player
## switches them on and off in the settings; the choice is saved next to the
## language (see the autoload Languages).

const RATE := 22050

## How many sounds play at once (besides the loops).
const PLAYERS := 8

## The notes of the tunes: a minor pentatonic scale on D, as the dombra plays
## it, by their degree (0 is D3).
const _SCALE := [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 392.0, 440.0, 523.25]

## The celebration: a rising phrase and a bright ending, [degree, beats].
const _TUNE := [[4, 0.5], [5, 0.5], [7, 0.5], [8, 1.0], [7, 0.5], [9, 1.5]]

## The background music: the melody of "Көзімнің қарасы" by Abai
## Qunanbaiuly (1845-1904), in the public domain, as [MIDI note, beats] in 2/4
## (see dev/music/kozimnin_karasi.py, which also writes it as a MIDI file).
const _SONG := [
    [50, 1],
    [52, 1],
    [54, 2],
    [54, 0.5],
    [52, 0.5],
    [54, 0.5],
    [52, 0.5],
    [59, 2],
    [59, 1],
    [61, 1],
    [62, 0.5],
    [55, 0.5],
    [59, 0.5],
    [62, 0.5],
    [61, 0.5],
    [59, 0.5],
    [62, 0.5],
    [61, 0.5],
    [59, 2],
    [66, 0.5],
    [64, 0.5],
    [62, 0.5],
    [59, 0.5],
    [64, 1.5],
    [66, 0.5],
    [69, 1],
    [71, 0.5],
    [69, 0.25],
    [71, 0.25],
    [66, 2],
    [61, 1],
    [62, 1],
    [64, 0.5],
    [55, 0.5],
    [59, 0.5],
    [61, 0.5],
    [62, 0.5],
    [64, 0.5],
    [61, 0.5],
    [57, 0.5],
    [59, 2],
]

## The song is played at this many seconds per beat (Andante).
const _SONG_BEAT := 0.72

## The open strings of the dombra, D3 and A3, strummed softly on every beat.
const _DRONE := [50, 57]

## The recorded sounds, by their names, each with its variants, of which
## [method play] picks one at random.
const _RECORDED := {
    "hoof": ["hoof"],
    "whinny": ["whinny"],
    "snort": ["snort"],
    "horse": ["whinny"],
    "sheep": ["sheep_1", "sheep_2"],
    "camel": ["camel"],
    "eagle": ["eagle_1", "eagle_2"],
    "falcon": ["falcon"],
    "swallow": ["swallow"],
    "lark": ["lark"],
    "marmot": ["marmot"],
    "locust": ["locust"],
}

## The loops of the hooves, by the gait (1 walks, 2 trots, 3 gallops), and how
## loud each plays, in dB.
const _HOOVES := ["hooves_walk", "hooves_trot", "hooves_gallop"]
const _HOOVES_DB := [-8.0, -6.0, -4.0]

## The hooves fade in and out this fast, in full volume per second.
const _HOOVES_FADE := 5.0

## Whether the sounds are on.
var enabled := true

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _meadow: AudioStreamPlayer
var _hooves: Array[AudioStreamPlayer] = []
var _hooves_gain: Array[float] = [0.0, 0.0, 0.0]
var _gait := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var settings := ConfigFile.new()
    if settings.load(get_node("/root/Languages").settings_path()) == OK:
        enabled = settings.get_value("general", "sound", true)
    for i in range(PLAYERS):
        var player := AudioStreamPlayer.new()
        add_child(player)
        _players.append(player)
    _music = AudioStreamPlayer.new()
    _music.volume_db = -16.0
    add_child(_music)
    _wind = AudioStreamPlayer.new()
    _wind.volume_db = -14.0
    add_child(_wind)
    _meadow = AudioStreamPlayer.new()
    _meadow.volume_db = -18.0
    add_child(_meadow)
    for i in range(_HOOVES.size()):
        var player := AudioStreamPlayer.new()
        player.stream = _recording(_HOOVES[i], true)
        player.volume_db = -80.0
        add_child(player)
        _hooves.append(player)
    music.call_deferred(true)


func _process(delta: float) -> void:
    # NOTE (mristin):
    # The loop of the gait fades in, the others fade out, so that the hooves
    # change smoothly from a walk to a trot to a gallop.
    for i in range(_hooves.size()):
        var player := _hooves[i]
        var target := 1.0 if enabled and _gait == i + 1 else 0.0
        _hooves_gain[i] = move_toward(_hooves_gain[i], target, _HOOVES_FADE * delta)
        if _hooves_gain[i] <= 0.0:
            if player.playing:
                player.stop()
            continue
        player.volume_db = _HOOVES_DB[i] + linear_to_db(_hooves_gain[i])
        if not player.playing:
            player.play(randf() * player.stream.get_length())


## Play the sound: "click", "chime", "call" or "tune" of the dombra, or a
## recorded one: "hoof", "whinny" and "snort" of the horse, the call of an
## animal by its kind ("sheep", "camel", "horse") or of a wild creature
## ("eagle", "falcon", "swallow", "lark", "marmot", "locust"); the pitch shifts
## it a little.
func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
    if not enabled:
        return
    var stream: AudioStream = null
    if _RECORDED.has(sound):
        var variants: Array = _RECORDED[sound]
        stream = _recording(variants[randi() % variants.size()], false)
    else:
        stream = _stream(sound)
    if stream == null:
        return
    for player in _players:
        if not player.playing:
            player.stream = stream
            player.pitch_scale = pitch
            player.volume_db = volume_db
            player.play()
            return


## Play the gentle music of the dombra in a loop, or stop it.
func music(on: bool) -> void:
    _loop(_music, _stream("music"), on)


## Let an animal of the kind call out: its own recorded call, or the call
## of the dombra for a kind without one.
func call_out(kind: String) -> void:
    if _RECORDED.has(kind):
        play(kind, randf_range(0.95, 1.08), -4.0)
    else:
        play("call")


## Play the steppe in a loop, the wind and the insects in the grass, or stop
## it.
func wind(on: bool) -> void:
    _loop(_wind, _recording("wind", true), on)
    _loop(_meadow, _recording("meadow", true), on)
    if not on:
        hooves(0)


## Let the hooves sound in the gait (0 stands, 1 walks, 2 trots, 3 gallops),
## in a loop until the gait changes.
func hooves(gait: int) -> void:
    _gait = clampi(gait, 0, _HOOVES.size())


## Switch the sounds on or off, and remember it.
func set_enabled(on: bool) -> void:
    enabled = on
    if not on:
        for player in _players:
            player.stop()
    _music.stream_paused = not on
    _wind.stream_paused = not on
    _meadow.stream_paused = not on
    var path: String = get_node("/root/Languages").settings_path()
    var settings := ConfigFile.new()
    settings.load(path)
    settings.set_value("general", "sound", on)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    settings.save(path)


func _loop(player: AudioStreamPlayer, stream: AudioStream, on: bool) -> void:
    if not on:
        player.stop()
        return
    if player.playing:
        return
    player.stream = stream
    player.stream_paused = not enabled
    player.play()


## The recording of assets/sounds/, looped or not.
func _recording(name: String, looped: bool) -> AudioStream:
    var key := "recorded/" + name
    if not _streams.has(key):
        # NOTE (mristin):
        # The recordings stay out of the cache of the resources: the audio
        # server may still hold one when the game quits, and the cache would
        # report it as left in use.
        var stream: AudioStreamOggVorbis = ResourceLoader.load(
            "res://assets/sounds/%s.ogg" % name, "", ResourceLoader.CACHE_MODE_IGNORE
        )
        stream.loop = looped
        _streams[key] = stream
    return _streams[key]


func _stream(sound: String) -> AudioStreamWAV:
    if not _streams.has(sound):
        var samples := PackedFloat32Array()
        match sound:
            "click":
                samples = _pluck(_SCALE[7], 0.18, 0.5)
            "chime":
                samples = _phrase([[5, 0.35], [7, 0.35], [9, 0.8]], 0.16, 0.6)
            "call":
                samples = _phrase([[4, 0.5], [2, 0.7]], 0.2, 0.5)
            "tune":
                samples = _phrase(_TUNE, 0.28, 0.8)
            "music":
                samples = _song(_SONG, _SONG_BEAT)
            _:
                return null
        var stream := _wav(samples)
        if sound == "music":
            stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            stream.loop_end = samples.size()
        _streams[sound] = stream
    return _streams[sound]


## A plucked string of the frequency (Karplus-Strong): a burst of noise in a
## delay line, which a gentle low-pass turns into a decaying tone.
func _pluck(frequency: float, seconds: float, loudness: float) -> PackedFloat32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(frequency * 100.0)
    var period := maxi(2, roundi(RATE / frequency))
    var line := PackedFloat32Array()
    line.resize(period)
    for i in range(period):
        line[i] = rng.randf_range(-1.0, 1.0)
    var count := roundi(seconds * RATE)
    var result := PackedFloat32Array()
    result.resize(count)
    var at := 0
    for i in range(count):
        var next := (at + 1) % period
        var value := line[at]
        line[at] = 0.497 * (line[at] + line[next])
        result[i] = value * loudness
        at = next
    return result


## The notes [degree, beats] one after the other, each ringing on under the
## next, at [param beat] seconds per beat.
func _phrase(notes: Array, beat: float, loudness: float) -> PackedFloat32Array:
    var total := 0.0
    for note in notes:
        total += note[1] * beat
    var result := PackedFloat32Array()
    result.resize(roundi((total + 0.6) * RATE))
    var start := 0.0
    for note in notes:
        var tone := _pluck(_SCALE[note[0]], note[1] * beat + 0.6, loudness)
        var offset := roundi(start * RATE)
        for i in range(tone.size()):
            if offset + i < result.size():
                result[offset + i] += tone[i]
        start += note[1] * beat
    return result


## The song plucked on the dombra, note by note, over a soft strum of its
## open strings on every beat, with a breath of silence before it repeats.
func _song(notes: Array, beat: float) -> PackedFloat32Array:
    var total := 0.0
    for note in notes:
        total += note[1] * beat
    var result := PackedFloat32Array()
    result.resize(roundi((total + beat) * RATE))
    var start := 0.0
    for note in notes:
        _mix(result, _pluck(_midi(note[0]), note[1] * beat + 0.5, 0.55), start)
        start += note[1] * beat
    for i in range(roundi(total / beat)):
        for k in range(_DRONE.size()):
            _mix(result, _pluck(_midi(_DRONE[k]), beat, 0.16), i * beat + 0.012 * k)
    return result


## Add the sound into the samples from the time on.
func _mix(samples: PackedFloat32Array, sound: PackedFloat32Array, at: float) -> void:
    var offset := roundi(at * RATE)
    for i in range(sound.size()):
        if offset + i >= samples.size():
            return
        samples[offset + i] += sound[i]


## The frequency of the MIDI note.
static func _midi(note: int) -> float:
    return 440.0 * pow(2.0, (note - 69) / 12.0)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in range(samples.size()):
        bytes.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0 * 0.9), -32768, 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.stereo = false
    stream.data = bytes
    return stream
