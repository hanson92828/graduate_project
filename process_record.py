from pydub import AudioSegment

def change_sample_rate(file_path, target_sample_rate):
    # 加載 MP3 文件
    audio = AudioSegment.from_mp3(file_path)

    # 更改取樣率
    audio = audio.set_frame_rate(target_sample_rate)

    # 保存修改後的音頻
    new_file_path = file_path.replace(".mp3", f"_{target_sample_rate}Hz.mp3")
    audio.export(new_file_path, format="mp3")

    return new_file_path