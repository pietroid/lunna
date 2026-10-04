import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Observable } from 'rxjs';
import { FIREBASE_STRATEGY_NAME } from './firebase.strategy';

@Injectable()
export class FirebaseAuthGuard extends AuthGuard(FIREBASE_STRATEGY_NAME) {
  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    return super.canActivate(context);
  }
}
