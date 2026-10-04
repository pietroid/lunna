import { Injectable } from '@nestjs/common';
import {
  DocumentSnapshot,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { SignUpUserDto } from './dto/signup-user.dto';
import { User } from './entities/user.entity';

function toOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function snapshotToUser(snapshot: DocumentSnapshot): User {
  const data = snapshot.data() as Record<string, unknown>;
  return {
    uid: data['uid'] as string,
    name: data['name'] as string | undefined,
    email: data['email'] as string | undefined,
    photoUrl: data['photoUrl'] as string | undefined,
    signupDate: (data['signupDate'] as Timestamp).toDate(),
  };
}

@Injectable()
export class UsersService {
  private readonly _collection = getFirestore().collection('users');

  async signUpUserIfNeeded(dto: SignUpUserDto): Promise<User> {
    const ref = this._collection.doc(dto.uid);
    const snapshot = await ref.get();

    if (snapshot.exists) {
      return snapshotToUser(snapshot);
    }

    const user: User = {
      uid: dto.uid,
      name: dto.name,
      signupDate: Timestamp.now().toDate(),
    };

    await ref.set(user);
    return user;
  }

  async getUser(uid: string): Promise<User | undefined> {
    const snapshot = await this._collection.doc(uid).get();
    if (!snapshot.exists) return undefined;
    return snapshotToUser(snapshot);
  }

  async enrichFromToken(user: User, token: DecodedIdToken): Promise<User> {
    const updates: Partial<User> = {};
    const tokenName = toOptionalString(token.name);
    const tokenEmail = toOptionalString(token.email);
    const tokenPicture = toOptionalString(token.picture);
    if (!user.name && tokenName) updates.name = tokenName;
    if (!user.email && tokenEmail) updates.email = tokenEmail;
    if (!user.photoUrl && tokenPicture) updates.photoUrl = tokenPicture;

    if (Object.keys(updates).length > 0) {
      await this._collection.doc(user.uid).update(updates);
      return { ...user, ...updates };
    }

    return user;
  }
}
