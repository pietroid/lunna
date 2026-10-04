import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { FirebaseAuthGuard } from './firebase-auth.guard';
import { FirebaseStrategy } from './firebase.strategy';

@Module({
  imports: [PassportModule],
  providers: [FirebaseStrategy, FirebaseAuthGuard],
  exports: [FirebaseStrategy, FirebaseAuthGuard],
})
export class AuthModule {}
