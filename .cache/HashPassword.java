import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public class HashPassword {
  public static void main(String[] args) {
    System.out.print("{bcrypt}" + new BCryptPasswordEncoder().encode("LifeQuestDemo!2026"));
  }
}
