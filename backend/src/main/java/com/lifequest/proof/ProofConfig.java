package com.lifequest.proof;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ProofConfig {

    @Bean
    ProofSettings proofSettings(
            @Value("${app.proof.min-votes:3}") int minVotes,
            @Value("${app.proof.agree-threshold:0.70}") double agreeThreshold,
            @Value("${app.proof.unclear-floor:0.40}") double unclearFloor,
            @Value("${app.proof.max-photos:5}") int maxPhotos,
            @Value("${app.proof.vote-exp:1}") int voteExp,
            @Value("${app.proof.daily-vote-exp-grants:5}") int dailyVoteExpGrants) {

        return new ProofSettings(
                minVotes, agreeThreshold, unclearFloor, maxPhotos, voteExp, dailyVoteExpGrants);
    }
}
