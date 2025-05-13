import express from 'express';
import * as osra from 'osra';  // Usando a biblioteca OSRA para OCR químico
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import axios from 'axios';

const router = express.Router();

// Configuração do Multer para upload de imagens
const upload = multer({ dest: 'uploads/' });

// Rota para processar OCR
router.post('/ocr', upload.single('image'), async (req, res) => {
    const imagePath = path.join(__dirname, '../', req.file.path);

    try {
        // Usando o OSRA para processar a imagem e extrair o SMILES
        osra.process(imagePath, async (error, result) => {
            if (error) {
                console.error('Erro ao processar a imagem:', error);
                return res.status(500).json({ error: 'Erro ao processar imagem' });
            }

            console.log('Resultado OCR:', result);

            // Agora vamos enviar o SMILES para o endpoint do Khemeia IA
            const iaResponse = await axios.post('https://khemeia.onrender.com/ai/analisar-molecula', {
                smiles: result.smiles
            });

            // Verifique a resposta da IA (que deve conter as questões)
            const analysisResult = iaResponse.data;

            // Retorna as questões da IA junto com o SMILES e nome da molécula
            return res.json({
                smiles: result.smiles,
                name: result.name,
                analysis: analysisResult // As questões geradas pela IA
            });

            // Deleta o arquivo temporário após o processamento
            fs.unlinkSync(imagePath);
        });
    } catch (error) {
        console.error('Erro inesperado:', error);
        return res.status(500).json({ error: 'Erro inesperado ao processar a imagem' });
    }
});

export default router;
