import { UserDoc } from '../models/user.model';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: { userId: string; role: 'user' | 'admin' };
      currentUser?: UserDoc;
    }
  }
}

export {};
