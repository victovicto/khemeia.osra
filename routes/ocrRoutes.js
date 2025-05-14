import express from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { exec } from 'child_process';

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

// OCR + análise IA
router.post('/ocr', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Nenhuma imagem recebida' });
    }

    const imagePath = path.resolve(req.file.path);
    console.log(`Processando imagem em: ${imagePath}`);

    // Executar OSRA via linha de comando para converter a imagem em SMILES
    exec(`osra ${imagePath}`, async (err, stdout, stderr) => {
      try {
        // Apagar o arquivo temporário após usar
        fs.unlink(imagePath, (unlinkErr) => {
          if (unlinkErr) console.error('Erro ao apagar arquivo temporário:', unlinkErr);
        });

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