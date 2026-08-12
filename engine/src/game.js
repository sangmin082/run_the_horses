// 말 달리자 — 매치 상태머신 (3라운드, 2선승, 라운드별 선공 교대)
import { P1, P2, initialBoard, opponent } from './board.js';
import { legalMoves, applyMove, isWinningMove } from './rules.js';

export const MAX_ROUNDS = 3;
export const WINS_NEEDED = 2;

export class Match {
  constructor() {
    this.roundWins = { [P1]: 0, [P2]: 0 };
    this.roundNumber = 0; // 1부터 시작 (startRound에서 증가)
    this.matchWinner = null;
    this.startRound();
  }

  // 라운드별 선공 교대: 1·3라운드 P1, 2라운드 P2
  startRound() {
    this.roundNumber += 1;
    this.board = initialBoard();
    this.turn = this.roundNumber % 2 === 1 ? P1 : P2;
    this.roundWinner = null;
    this.history = [];
  }

  legalMoves() {
    if (this.roundWinner !== null || this.matchWinner !== null) return [];
    return legalMoves(this.board, this.turn);
  }

  // 현재 차례 플레이어의 이동을 적용. 라운드/매치 종료를 갱신하고 결과를 반환.
  play(move) {
    if (this.roundWinner !== null || this.matchWinner !== null) {
      throw new Error('라운드가 이미 종료됨');
    }
    applyMove(this.board, move);
    this.history.push({ ...move, player: this.turn });

    if (isWinningMove(move)) {
      this.roundWinner = this.turn;
      this.roundWins[this.turn] += 1;
      if (this.roundWins[this.turn] >= WINS_NEEDED) {
        this.matchWinner = this.turn;
      }
      return { roundOver: true, matchOver: this.matchWinner !== null, winner: this.turn };
    }

    this.turn = opponent(this.turn);
    return { roundOver: false, matchOver: false, winner: null };
  }

  // 라운드 종료 후 다음 라운드로 진행 (매치가 끝나지 않았을 때만)
  nextRound() {
    if (this.matchWinner !== null) throw new Error('매치가 이미 종료됨');
    if (this.roundWinner === null) throw new Error('라운드가 아직 진행 중');
    this.startRound();
  }
}
