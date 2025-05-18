import express, { json } from 'express';
import cors from 'cors';
import ocrRoutes from './routes/ocrRoutes.js';

const app = express();
const port = process.env.PORT || 3003;

// Middleware
app.use(cors());
app.use(json());

// Rota de raiz para verificação rápida
app.get('/', (req, res) => {
  res.json({ 
    status: 'OSRA OCR API Ativa',
    version: '1.0.0',
    message: 'Use /ocrRoutes/ocr para processar imagens de estruturas químicas'
  });
});

// Usando as rotas OCR
app.use('/ocrRoutes', ocrRoutes);

// Iniciar o servidor
app.listen(port, '0.0.0.0', () => {
  console.log(`Servidor OCR rodando na porta ${port}`);
});