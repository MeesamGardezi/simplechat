import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import { getDb } from './db';
import joinRoutes from './routes/join';
import roomRoutes from './routes/rooms';
import messageRoutes from './routes/messages';
import { registerSocketHandlers } from './socket/handlers';

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

app.use(cors());
app.use(express.json());

getDb();

app.use('/api/auth', joinRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/messages', messageRoutes);
app.get('/health', (_, res) => res.json({ status: 'ok' }));

registerSocketHandlers(io);

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => console.log(`SimpleChat running on :${PORT}`));
