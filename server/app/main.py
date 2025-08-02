from fastapi import FastAPI
from starlette.middleware.cors import CORSMiddleware

from app.api.train_api import router as training_router

import uvicorn

app = FastAPI()
app.include_router(training_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 중에는 * (모든 origin 허용). 실제 서비스 배포시 도메인 제한 필요
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)