import asyncio
import os
import websockets
import websockets.exceptions
from process_video import change_mp4_to_mp3
from process_record import change_sample_rate
from transformers import pipeline

pipe = pipeline(model="hanson92828/whisper-small-chinese")
keyword = '錄音'
connected_clients = set()
i = 1

async def Flow(websocket, path):
    print(websocket)
    connected_clients.add(websocket)
    print(connected_clients)
    video_data = b''
    global i
    file_name = str(i)
    
    i += 1

    try:
        async for message in websocket:
            if message != 'EOF':
                video_data += message
            else:
                print(message)
                with open(file_name+'.mp4', 'wb') as f:
                    f.write(video_data)
                change_mp4_to_mp3(file_name+'.mp4','','')
                change_sample_rate(file_name+'.mp3',16000)
                # await websocket.send("hello")
                user_path = 'D:/graduateproject/'
                try:
                    result =  pipe(user_path + file_name + '_16000Hz.mp3')
                except Exception as e:
                    print(f"Whisper failed: {e}")
                    await websocket.send(f"error: whisper failed - {e}")
                
                print(keyword)
                print(result['text'])
                
                try: 
                    if keyword in result['text']:
                        try:
                            await websocket.send("yes")
                            print('send yes to your flutter')
                        except Exception as e:
                            print(f'failed {e}')
                    else:
                        try:
                            await websocket.send("no")
                            print('send no to your flutter')
                        except Exception as e:
                            print(f'failed {e}')
                except Exception as e:
                            print(f'notsuccess {e}')        

                # os.remove(file_name + '.mp3')
                # os.remove(file_name + '.mp4')
                # os.remove(file_name + '16000Hz.mp3')
                # connected_clients.remove(websocket)
    except:
        connected_clients.remove(websocket)

async def MessageHandler(socket,message):
    try:
        print(f"{message} from socket {socket}")
    except websockets.exceptions.ConnectionClosed:
        raise BufferError("client disconnect")
    
async def SendMessage(socket,message):
    try:
        socket.send(message)
    except:
        raise TimeoutError("send fail")

async def main():
    async with websockets.serve(Flow, '192.168.50.144', 1125, max_size=10*1024*1024):
        print("WebSocket server started on ws://192.168.1.143:4572")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())