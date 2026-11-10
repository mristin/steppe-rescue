extends Node

## Play the sounds of the game (see section 11 of DESIGN.md), all synthesized
## here, so that the game needs no sound files and no licenses for them: the
## plucked strings of a dombra (Karplus-Strong) for the gentle music, the
## celebration tune and the clicks, a low thud for the hooves, and filtered
## noise for the wind of the steppe.
##
## The sounds are made the first time they are played and kept. The player
## switches them on and off in the settings; the choice is saved next to the
## language (see the autoload Languages).

const RATE := 22050

## The notes of the tunes: a minor pentatonic scale on D, as the dombra plays
## it, by their degree (0 is D3).
const _SCALE := [146.83, 174.61, 196.0, 220.0, 261.63, 293.66, 349.23, 392.0, 440.0, 523.25]

## The celebration: a rising phrase and a bright ending, [degree, beats].
const _TUNE := [[4, 0.5], [5, 0.5], [7, 0.5], [8, 1.0], [7, 0.5], [9, 1.5]]

## The gentle music: a strummed pattern of the dombra, looped.
const _MUSIC := [
    [0, 1],
    [4, 0.5],
    [3, 0.5],
    [2, 1],
    [4, 1],
    [0, 1],
    [3, 0.5],
    [2, 0.5],
    [1, 1],
    [2, 1],
    [0, 1],
    [4, 0.5],
    [5, 0.5],
    [4, 1],
    [3, 1],
    [2, 1],
    [1, 0.5],
    [2, 0.5],
    [0, 2],
]

## Whether the sounds are on.
var enabled := true

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _wind: AudioStreamPlayer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var settings := ConfigFile.new()
    if settings.load(get_node("/root/Languages").settings_path()) == OK:
        enabled = settings.get_value("general", "sound", true)
    for i in range(6):
        var player := AudioStreamPlayer.new()
        add_child(player)
        _players.append(player)
    _music = AudioStreamPlayer.new()
    _music.volume_db = -16.0
    add_child(_music)
    _wind = AudioStreamPlayer.new()
    _wind.volume_db = -22.0
    add_child(_wind)
    music.call_deferred(true)


## Play the sound: "click", "chime", "tune", "hoof" or "stamp"; the pitch
## shifts it a little, e.g., for the hooves at a gallop.
func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
    if not enabled:
        return
    var stream := _stream(sound)
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
    _loop(_music, "music", on)


## Play the wind of the steppe in a loop, or stop it.
func wind(on: bool) -> void:
    _loop(_wind, "wind", on)


## Switch the sounds on or off, and remember it.
func set_enabled(on: bool) -> void:
    enabled = on
    if not on:
        for player in _players:
            player.stop()
    _music.stream_paused = not on
    _wind.stream_paused = not on
    var path: String = get_node("/root/Languages").settings_path()
    var settings := ConfigFile.new()
    settings.load(path)
    settings.set_value("general", "sound", on)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    settings.save(path)


func _loop(player: AudioStreamPlayer, sound: String, on: bool) -> void:
    if not on:
        player.stop()
        return
    if player.playing:
        return
    player.stream = _stream(sound)
    player.stream_paused = not enabled
    player.play()


func _stream(sound: String) -> AudioStreamWAV:
    if not _streams.has(sound):
        var samples := PackedFloat32Array()
        match sound:
            "click":
                samples = _pluck(_SCALE[7], 0.18, 0.5)
            "chime":
                samples = _phrase([[5, 0.35], [7, 0.35], [9, 0.8]], 0.16, 0.6)
            "tune":
                samples = _phrase(_TUNE, 0.28, 0.8)
            "music":
                samples = _phrase(_MUSIC, 0.42, 0.5)
            "hoof":
                samples = _thud(0.12, 90.0)
            "stamp":
                samples = _thud(0.2, 70.0)
            "wind":
                samples = _wind_noise(6.0)
            _:
                return null
        var stream := _wav(samples)
        if sound in ["music", "wind"]:
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


## A thud of a hoof on the ground: a low, quickly falling tone with a click.
func _thud(seconds: float, frequency: float) -> PackedFloat32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = roundi(frequency)
    var count := roundi(seconds * RATE)
    var result := PackedFloat32Array()
    result.resize(count)
    var phase := 0.0
    for i in range(count):
        var t := float(i) / RATE
        var fall := exp(-t * 30.0)
        phase += TAU * frequency * (1.0 + fall) / RATE
        var click := rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)
        result[i] = (sin(phase) * 0.8 + click * 0.4) * fall
    return result


## The wind: noise, low-passed and swelling slowly, which loops seamlessly.
func _wind_noise(seconds: float) -> PackedFloat32Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var count := roundi(seconds * RATE)
    var result := PackedFloat32Array()
    result.resize(count)
    var low := 0.0
    for i in range(count):
        low += (rng.randf_range(-1.0, 1.0) - low) * 0.02
        var swell := 0.6 + 0.4 * sin(TAU * i / count * 2.0)
        result[i] = low * 4.0 * swell
    return result


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
