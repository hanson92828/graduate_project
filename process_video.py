from moviepy.video.io.VideoFileClip import VideoFileClip
from moviepy.editor import *

def change_mp4_to_mp3(input_file,input_path,output_path):
    video_path = input_path+input_file
    video = VideoFileClip(video_path)
    file_name,file_type = input_file.split('.')
    output_file = file_name + '.mp3'
    video.audio.write_audiofile(output_path+output_file)