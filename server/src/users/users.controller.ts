import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import * as adminAuth from 'firebase-admin/auth';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { SignUpUserDto } from './dto/signup-user.dto';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';

type DecodedIdToken = adminAuth.DecodedIdToken;

function toOptionalString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('signup')
  @UseGuards(FirebaseAuthGuard)
  async signUp(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: SignUpUserDto,
  ): Promise<User> {
    // Use the UID from the verified token to prevent spoofing.
    const createdUser = await this.usersService.signUpUserIfNeeded({
      uid: user.uid,
      name: toOptionalString(dto.name ?? user.name),
    });

    return this.usersService.enrichFromToken(createdUser, user);
  }

  @Get('me')
  @UseGuards(FirebaseAuthGuard)
  async getMe(@CurrentUser() user: DecodedIdToken): Promise<User> {
    const profile = await this.usersService.getUser(user.uid);
    if (!profile) {
      return this.usersService.signUpUserIfNeeded({
        uid: user.uid,
        name: toOptionalString(user.name),
      });
    }
    return this.usersService.enrichFromToken(profile, user);
  }
}
