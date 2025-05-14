import express, { json } from 'express';
import cors from 'cors';  // Se você precisar permitir requisições de outros domínios
import ocrRoutes from './routes/ocrRoutes.js';  // Importando as rotas OCR

const app = express();
const port = 3003;

// Middleware
app.use(cors());
app.use(json());  // Se você estiver trabalhando com JSON

// Usando as rotas OCR
app.use('/ocrRoutes', ocrRoutes);

// Iniciar o servidor
app.listen(port, () => {
  console.log(`Servidor OCR rodando na porta ${port}`);
});
