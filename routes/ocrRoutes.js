import express from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { exec } from 'child_process';
import bodyParser from 'body-parser';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obter o diretório atual do módulo ES
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const uploadDir = path.join(__dirname, '../uploads');

const router = express.Router();
const upload = multer({ 
  dest: uploadDir,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limite
});

// Middleware para aumentar o limite de tamanho do corpo
router.use(bodyParser.raw({ 
  type: 'application/octet-stream',
  limit: '10mb' 
}));

// Função para criar o diretório de uploads se não existir
const ensureUploadsDirectory = () => {
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }
};

// Garantir que o diretório de uploads exista quando o aplicativo inicia
ensureUploadsDirectory();

// Função auxiliar para executar o OSRA com timeout
const runOsra = (imagePath) => {
  return new Promise((resolve, reject) => {
    // Verificar se o arquivo existe
    if (!fs.existsSync(imagePath)) {
      return reject(new Error(`Arquivo não encontrado: ${imagePath}`));
    }
    
    // Registrar tamanho do arquivo para depuração
    const stats = fs.statSync(imagePath);
    console.log(`Processando arquivo de ${stats.size} bytes: ${imagePath}`);

    // Executar comando OSRA com timeout
    const timeout = 30000; // 30 segundos
    const osraProcess = exec(`osra ${imagePath}`, { timeout }, (err, stdout, stderr) => {
      if (err) {
        console.error('Erro ao executar OSRA:', err);
        console.error('Saída de erro:', stderr);
        
        // Se for erro de timeout
        if (err.signal === 'SIGTERM') {
          return reject(new Error('OSRA demorou muito tempo para processar a imagem'));
        }
        
        return reject(new Error(`Falha ao executar OSRA: ${err.message}`));
      }
      
      const smiles = stdout.trim();
      if (!smiles) {
        console.warn('OSRA não detectou estrutura química na imagem');
        return reject(new Error('Estrutura química não detectada na imagem'));
      }
      
      console.log(`SMILES obtido: ${smiles}`);
      resolve(smiles);
    });
  });
};

// OCR com suporte a multipart/form-data E application/octet-stream
router.post('/ocr', async (req, res) => {
  let imagePath;
  let shouldDeleteFile = false;

  try {
    ensureUploadsDirectory();
    
    // Verificar o tipo de conteúdo
    const contentType = req.headers['content-type'] || '';

    // Caso 1: application/octet-stream (envio de bytes direto)
    if (contentType.includes('application/octet-stream')) {
      console.log('Recebendo imagem via octet-stream');
      // Criar arquivo temporário para os bytes recebidos
      imagePath = path.join(uploadDir, `temp-${Date.now()}.png`);
      
      // Verificar se os dados da imagem estão presentes
      if (!req.body || req.body.length === 0) {
        return res.status(400).json({ error: 'Dados da imagem vazios ou inválidos' });
      }
      
      console.log(`Recebido ${req.body.length} bytes de dados`);
      
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

    try {
      // Executar OSRA para obter o SMILES
      const smiles = await runOsra(imagePath);
      
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
          details: iaError?.response?.data || iaError.message,
          smiles: smiles // Retornar o SMILES mesmo com erro na IA
        });
      }
    } catch (osraError) {
      console.error('Erro no processamento OSRA:', osraError);
      return res.status(500).json({ error: 'Falha ao extrair estrutura química', details: osraError.message });
    }
  } catch (error) {
    console.error('Erro interno no OCR:', error);
    return res.status(500).json({ error: 'Erro interno no servidor', details: error.message });
  } finally {
    // Tentar limpar arquivo se existir
    if (shouldDeleteFile && imagePath) {
      try {
        fs.unlinkSync(imagePath);
        console.log(`Arquivo temporário removido: ${imagePath}`);
      } catch (unlinkErr) {
        console.error('Erro ao apagar arquivo temporário:', unlinkErr);
      }
    }
  }
});

// Rota de health check avançada
router.get('/ping', (req, res) => {
  // Verificar se o OSRA está instalado
  exec('which osra', (err, stdout) => {
    const osraInstalled = !err && stdout.trim();
    
    // Verificar diretório de uploads
    const uploadsExists = fs.existsSync(uploadDir);
    
    return res.json({ 
      status: osraInstalled ? 'OK' : 'OSRA não encontrado', 
      timestamp: new Date().toISOString(),
      osra_installed: !!osraInstalled,
      osra_path: osraInstalled ? stdout.trim() : null,
      uploads_dir: uploadDir,
      uploads_exists: uploadsExists,
      node_env: process.env.NODE_ENV || 'development',
      version: '1.0.0'
    });
  });
});

export default router;