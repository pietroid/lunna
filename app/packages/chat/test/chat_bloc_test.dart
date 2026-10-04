import 'package:bloc_test/bloc_test.dart';
import 'package:chat/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late ChatRepository repository;

  final thread = Thread.fromJson(const {
    'slug': 'escrever',
    'title': 'Escrever',
    'messages': [
      {'id': '1', 'role': 'user', 'text': 'Oi'},
    ],
  });

  setUp(() {
    repository = _MockChatRepository();
    when(
      () => repository.sendMessage(any(), any()),
    ).thenAnswer((_) async => thread);
  });

  group('ChatBloc with a thread starter', () {
    blocTest<ChatBloc, ChatState>(
      'starts the thread on the first message and writes into it',
      build: () => ChatBloc(
        chatRepository: repository,
        threadStarter: () async => 'escrever',
      ),
      act: (bloc) => bloc.add(const ChatMessageSent('Oi')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        verify(() => repository.sendMessage('escrever', 'Oi')).called(1);
        verifyNever(() => repository.createThread(any()));
        expect(bloc.state.slug, 'escrever');
      },
    );
  });
}
