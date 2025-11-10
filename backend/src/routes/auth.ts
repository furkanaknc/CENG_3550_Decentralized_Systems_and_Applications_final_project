import { Router } from 'express';
import { login, getProfile } from '../controllers/authController';
import { authenticateWallet } from '../middleware/auth';

const router = Router();

router.post('/login', login);
router.get('/profile', authenticateWallet, getProfile);

export default router;

