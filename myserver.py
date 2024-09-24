import asyncio
import websockets
import websockets.exceptions
from process_video import change_mp4_to_mp3
from process_record import change_sample_rate

# 用來保存已連接的客戶端
connected_clients = set()

async def Flow(websocket, path):
    # 將新的客戶端添加到已連接的客戶端集合中
    print(websocket)
    connected_clients.add(websocket)
    video_data = b''
    try:
        async for message in websocket:
            if message != 'EOF':
                video_data += message
            else:
                with open('received_video.mp4', 'wb') as f:
                    f.write(video_data)
                await MessageHandler(websocket,message)
                change_mp4_to_mp3('received_video.mp4','','')
                change_sample_rate('received_video.mp3',16000)

        # await SendMessage(websocket,"sth")
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
    async with websockets.serve(Flow, '192.168.1.115', 8765):
        print("WebSocket server started on ws://192.168.1.115:8765")
        await asyncio.Future()  # 保持伺服器運行

if __name__ == "__main__":
    asyncio.run(main())
