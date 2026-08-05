package com.lifequest.recommendation;
import com.lifequest.common.exception.*;import java.net.http.HttpTimeoutException;import org.springframework.web.client.*;
final class ProviderHttpSupport {
 private ProviderHttpSupport(){}
 static BusinessException map(Exception e){
  if(e instanceof RestClientResponseException r){int s=r.getStatusCode().value();if(s==401||s==403)return new BusinessException(ErrorCode.LLM_NOT_CONFIGURED);if(s==429)return new BusinessException(ErrorCode.LLM_PROVIDER_RATE_LIMITED);return new BusinessException(ErrorCode.LLM_PROVIDER_ERROR);}
  Throwable c=e;while(c!=null){if(c instanceof java.net.SocketTimeoutException||c instanceof HttpTimeoutException)return new BusinessException(ErrorCode.LLM_PROVIDER_TIMEOUT);c=c.getCause();}return new BusinessException(ErrorCode.LLM_PROVIDER_ERROR);
 }
}
