import express from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { exec } from 'child_process';
import bodyParser from 'body-parser';

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

// Middleware para aumentar o limite de tamanho do corpo
router.use(bodyParser.raw({ 
  type: 'application/octet-stream',
  limit: '10mb' 
}));

// OCR com suporte a multipart/form-data E application/octet-stream
router.post('/ocr', async (req, res) => {
  try {
    let imagePath;
    let shouldDeleteFile = false;

    // Verificar o tipo de conteúdo
    const contentType = req.headers['content-type'] || '';

    // Caso 1: application/octet-stream (envio de bytes direto)
    if (contentType.includes('application/octet-stream')) {
      console.log('Recebendo imagem via octet-stream');
      // Criar arquivo temporário para os bytes recebidos
      imagePath = path.join('uploads', `temp-${Date.now()}.png`);

      // Garantir que o diretório existe
      if (!fs.existsSync('uploads')) {
        fs.mkdirSync('uploads', { recursive: true });
      }

      // Escrever os bytes no arquivo temporário
      fs.writeFileSync(imagePath, req.body);
      shouldDeleteFile = true;
    }
    // Caso 2: multipart/form-data (formulário com arquivo)
    else if (contentType.includes('multipart/form-data')) {
      console.log('Recebendo imagem via multipart/form-data');
      // Usar multer para processar a requisição
      const processUpload = () => {
        return new Promise((resolve, reject) => {
          upload.single('image')(req, res, (err) => {
            if (err) return reject(err);
            if (!req.file) return reject(new Error('Nenhuma imagem recebida'));
            resolve(req.file.path);
          });
        });
      };

      imagePath = await processUpload();
      shouldDeleteFile = true;
    } else {
      return res.status(400).json({ 
        error: 'Formato não suportado', 
        message: 'Use application/octet-stream ou multipart/form-data' 
      });
    }

    console.log(`Processando imagem em: ${imagePath}`);

    // Executar OSRA via linha de comando para converter a imagem em SMILES
    exec(`osra ${imagePath}`, async (err, stdout, stderr) => {
      try {
        // Apagar o arquivo temporário após usar
        if (shouldDeleteFile && imagePath) {
          fs.unlink(imagePath, (unlinkErr) => {
            if (unlinkErr) console.error('Erro ao apagar arquivo temporário:', unlinkErr);
          });
        }

        if (err || !stdout.trim()) {
          console.error('Erro ao rodar OSRA:', stderr || err);
          return res.status(500).json({ error: 'Falha ao extrair estrutura química' });
        }

        const smiles = stdout.trim();
        console.log(`SMILES obtido: ${smiles}`);

        // Chamar o backend da IA com o SMILES obtido
        try {
          const respostaIA = await axios.post('https://khemeia.onrender.com/ai/analisar-molecula', {
            formato: 'smiles',
            estrutura: smiles
          });

          // Enviar as perguntas e o nome da molécula de volta para o cliente
          const result = {
            perguntas: respostaIA.data?.perguntas || [],
            nome: respostaIA.data?.nome || 'Molécula desconhecida',
            smiles: smiles
          };

          console.log(`Perguntas obtidas: ${result.perguntas.length}`);
          return res.json(result);

        } catch (iaError) {
          console.error('Erro ao chamar a IA:', iaError?.response?.data || iaError.message);
          return res.status(500).json({ 
            error: 'Falha ao obter análise da IA',
            details: iaError?.response?.data || iaError.message
          });
        }
      } catch (finalError) {
        console.error('Erro durante o processamento:', finalError);
        return res.status(500).json({ error: 'Erro interno no processamento' });
      }
    });
  } catch (error) {
    console.error('Erro interno no OCR:', error);
    // Tentar limpar arquivo se existir, mesmo em erro
    if (req.file && req.file.path) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (unlinkErr) {
        console.error('Erro ao apagar arquivo em exception:', unlinkErr);
      }
    }
    return res.status(500).json({ error: 'Erro interno no servidor' });
  }
});

// Rota de health check
router.get('/ping', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

export default router;
