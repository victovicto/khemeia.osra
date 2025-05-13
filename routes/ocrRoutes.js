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
  const imagePath = path.resolve(req.file.path);

  try {
    // Executar OSRA via linha de comando
    exec(`osra ${imagePath}`, async (err, stdout, stderr) => {
      // Apagar o arquivo mesmo em erro
      fs.unlinkSync(imagePath);

      if (err || !stdout.trim()) {
        console.error('Erro ao rodar OSRA:', stderr || err);
        return res.status(500).json({ error: 'Falha ao extrair estrutura química' });
      }

      const smiles = stdout.trim();

      // Chamar backend principal da IA com o SMILES
      try {
        const respostaIA = await axios.post('https://khemeia.onrender.com/ai/analisar-molecula', {
          formato: 'smiles',
          estrutura: smiles
        });

        const perguntas = respostaIA.data?.perguntas || [];

        return res.json({ perguntas });

      } catch (iaError) {
        console.error('Erro ao chamar a IA:', iaError?.response?.data || iaError.message);
        return res.status(500).json({ error: 'Falha ao obter análise da IA' });
      }
    });
  } catch (error) {
    console.error('Erro interno no OCR:', error);
    return res.status(500).json({ error: 'Erro interno no servidor' });
  }
});

export default router;
